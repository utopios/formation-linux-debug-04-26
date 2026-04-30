#!/usr/bin/env bash
# setup-m7-tp05-orderapi.sh
# TP 5 (Module 7) - API HTTP factice + flock_holder pour reproduire latence intermittente.
# Apt requis : python3 systemd bpftrace
# IMPORTANT : ce script doit etre lance avec sudo.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/orderapi
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"

cat > "$INSTALL_DIR/orderapi.py" <<'EOF'
#!/usr/bin/env python3
"""orderapi - service HTTP factice avec une latence intermittente cachee."""
import fcntl
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

CACHE_FILE = "/var/lib/orderapi/cache.json"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._reply(200, {"status": "ok"})
            return
        if self.path == "/orders":
            self._handle_orders()
            return
        self._reply(404, {"error": "not found"})

    def _handle_orders(self):
        with open(CACHE_FILE, "r") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_SH)
            try:
                data = json.load(f)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        self._reply(200, {"orders": data.get("orders", [])})

    def _reply(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return

def init_cache():
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    if not os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, "w") as f:
            json.dump({"orders": [{"id": i, "amount": i * 10} for i in range(100)]}, f)

if __name__ == "__main__":
    init_cache()
    print(f"orderapi starting on :8080 (PID {os.getpid()})", flush=True)
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
EOF

cat > "$INSTALL_DIR/flock_holder.py" <<'EOF'
#!/usr/bin/env python3
"""flock_holder - prend un flock exclusif pendant 3 min."""
import fcntl
import os
import time

CACHE_FILE = "/var/lib/orderapi/cache.json"
HOLD_SECONDS = 180

def main():
    if not os.path.exists(CACHE_FILE):
        print("cache file not present, nothing to lock", flush=True)
        return
    with open(CACHE_FILE, "r+") as f:
        print(f"flock_holder PID {os.getpid()} acquiring exclusive lock for {HOLD_SECONDS}s", flush=True)
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            time.sleep(HOLD_SECONDS)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
            print("flock_holder released", flush=True)

if __name__ == "__main__":
    main()
EOF

chmod 0755 "$INSTALL_DIR/orderapi.py" "$INSTALL_DIR/flock_holder.py"

cat > /etc/systemd/system/orderapi.service <<'EOF'
[Unit]
Description=orderapi - service HTTP factice (TP 5)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/orderapi/orderapi.py
StandardOutput=journal
StandardError=journal
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/orderapi-flock.service <<'EOF'
[Unit]
Description=orderapi-flock - prend un flock pendant 3 min (TP 5)

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /opt/orderapi/flock_holder.py
StandardOutput=journal
StandardError=journal
EOF

systemctl daemon-reload

cat <<EOF

[setup] OK : $INSTALL_DIR/ et 2 services systemd crees.

A executer :
  sudo systemctl start orderapi.service
  curl -s http://localhost:8080/health

  # Declencher la latence intermittente
  sudo systemctl start orderapi-flock.service

  # Cote client, mesurer la latence
  while true; do
    start=\$(date +%s%N); curl -s http://localhost:8080/orders > /dev/null; end=\$(date +%s%N)
    echo "\$(date +%T) latency_ms=\$(( (end - start) / 1000000 ))"
    sleep 0.5
  done

  # Cote diagnostic (bpftrace)
  sudo bpftrace -e 'kprobe:vfs_read /comm == "python3"/ { @start[tid] = nsecs; }
                    kretprobe:vfs_read /@start[tid]/
                    { @ms = hist((nsecs - @start[tid]) / 1000000); delete(@start[tid]); }'

Reset apres TP :
  sudo systemctl stop orderapi.service orderapi-flock.service 2>/dev/null || true
EOF
