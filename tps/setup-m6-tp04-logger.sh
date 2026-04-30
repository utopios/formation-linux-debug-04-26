#!/usr/bin/env bash
# setup-m6-tp04-logger.sh
# TP 4 (Module 6) - service qui ecrit ~500 lignes/s avec fsync (vrai coupable).
# Apt requis : python3 sysstat iotop
# IMPORTANT : ce script doit etre lance avec sudo. A coupler avec setup-m6-tp04-archiver.sh.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/logger
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"
install -d -m 0755 /var/log/logger

cat > "$INSTALL_DIR/logger.py" <<'EOF'
#!/usr/bin/env python3
"""logger - ecrit des petites lignes de log + fsync a chaque entree."""
import os
import time

LOG_DIR = "/var/log/logger"
LOG_FILE = os.path.join(LOG_DIR, "app.log")

def main():
    os.makedirs(LOG_DIR, exist_ok=True)
    print(f"logger starting (PID {os.getpid()}), writing to {LOG_FILE}", flush=True)
    counter = 0
    with open(LOG_FILE, "a", buffering=1) as f:
        while True:
            counter += 1
            f.write(f"{time.time():.3f} INFO request id={counter} status=200\n")
            f.flush()
            os.fsync(f.fileno())
            time.sleep(0.002)

if __name__ == "__main__":
    main()
EOF

chmod 0755 "$INSTALL_DIR/logger.py"

cat > /etc/systemd/system/logger.service <<'EOF'
[Unit]
Description=logger - service ecrivant des logs avec fsync (TP 4)

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/logger/logger.py
StandardOutput=journal
StandardError=journal
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

