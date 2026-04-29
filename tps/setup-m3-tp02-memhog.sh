#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/memhog
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"

cat > "$INSTALL_DIR/memhog.py" <<'EOF'
#!/usr/bin/env python3
"""memhog - service avec une fuite memoire deterministe."""
import os
import time

_cache = []

def cache_lookup(key):
    payload = bytearray(32 * 1024 * 1024)
    _cache.append((key, payload))
    return payload[0]

def main():
    print(f"memhog starting (PID {os.getpid()})", flush=True)
    counter = 0
    while True:
        counter += 1
        cache_lookup(counter)
        total_mb = len(_cache) * 32
        print(f"served request {counter}, cache={total_mb} MB", flush=True)
        time.sleep(5)

if __name__ == "__main__":
    main()
EOF

chmod 0755 "$INSTALL_DIR/memhog.py"

cat > /etc/systemd/system/memhog.service <<'EOF'
[Unit]
Description=memhog - service avec fuite memoire (TP 2)

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/memhog/memhog.py
StandardOutput=journal
StandardError=journal
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Swap pour bien voir si/so avant OOM
if ! swapon --show | grep -q '/swapfile-memhog'; then
    fallocate -l 512M /swapfile-memhog
    chmod 600 /swapfile-memhog
    mkswap /swapfile-memhog > /dev/null
    swapon /swapfile-memhog
    grep -q '/swapfile-memhog' /etc/fstab || echo '/swapfile-memhog none swap sw 0 0' >> /etc/fstab
fi

