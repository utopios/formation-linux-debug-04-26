#!/usr/bin/env bash

set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_DIR="$TARGET_HOME/demo-linux"

echo "[setup] preparation de $TARGET_DIR/freeze.py"

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_DIR"

cat > "$TARGET_DIR/freeze.py" <<'EOF'
#!/usr/bin/env python3
"""Process qui freeze sur un connect TCP vers une IP non routable."""
import os
import socket

print("PID", os.getpid(), flush=True)

s = socket.socket()
s.settimeout(600)

print("connect...", flush=True)
try:
    s.connect(("10.255.255.1", 9))
except Exception as e:
    print("err", e, flush=True)

print("done", flush=True)
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/freeze.py"
chmod 0644 "$TARGET_DIR/freeze.py"