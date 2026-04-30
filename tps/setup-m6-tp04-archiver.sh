#!/usr/bin/env bash
# setup-m6-tp04-archiver.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/archiver
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"
install -d -m 0755 /var/archive

cat > "$INSTALL_DIR/archiver.py" <<'EOF'
#!/usr/bin/env python3
"""archiver - ecrit des chunks de 1 Mo sans fsync (asynchrone)."""
import os
import time

ARCHIVE_DIR = "/var/archive"

def main():
    os.makedirs(ARCHIVE_DIR, exist_ok=True)
    print(f"archiver starting (PID {os.getpid()}), writing to {ARCHIVE_DIR}", flush=True)
    counter = 0
    chunk = bytearray(1024 * 1024)
    while True:
        counter += 1
        path = os.path.join(ARCHIVE_DIR, f"chunk-{counter % 50:04d}.bin")
        with open(path, "wb") as f:
            f.write(chunk)
        time.sleep(0.1)

if __name__ == "__main__":
    main()
EOF

chmod 0755 "$INSTALL_DIR/archiver.py"

cat > /etc/systemd/system/archiver.service <<'EOF'
[Unit]
Description=archiver - service ecrivant des chunks 1 Mo (TP 4)

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/archiver/archiver.py
StandardOutput=journal
StandardError=journal
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

