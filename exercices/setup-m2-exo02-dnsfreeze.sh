#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_DIR="$TARGET_HOME/demo-linux"

echo "[setup] preparation de $TARGET_DIR/dns_freeze.py"

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_DIR"

cat > "$TARGET_DIR/dns_freeze.py" <<'EOF'
#!/usr/bin/env python3
"""Process qui freeze sur un recvfrom() UDP en attente d'une reponse DNS.
"""
import os
import socket
import struct

print("PID", os.getpid(), flush=True)

# Serveur DNS volontairement non joignable (IP non routable)
DNS_SERVER = ("10.255.255.1", 53)

# Construire une requete DNS minimale pour example.com (type A)
# Header (12 octets) + question
txid = 0x1234
flags = 0x0100  # standard query, recursion desired
qd_count = 1
header = struct.pack("!HHHHHH", txid, flags, qd_count, 0, 0, 0)

# Encoder le nom "example.com" au format DNS (length-prefixed labels + \0)
def encode_name(name):
    out = b""
    for label in name.split("."):
        out += bytes([len(label)]) + label.encode()
    return out + b"\x00"

question = encode_name("example.com") + struct.pack("!HH", 1, 1)  # QTYPE=A, QCLASS=IN
query = header + question

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(600)

print(f"sending DNS query to {DNS_SERVER[0]}:{DNS_SERVER[1]} ...", flush=True)
s.sendto(query, DNS_SERVER)

print("waiting reply...", flush=True)
try:
    data, addr = s.recvfrom(4096)
    print("got reply", len(data), "bytes from", addr, flush=True)
except Exception as e:
    print("err", e, flush=True)

print("done", flush=True)
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/dns_freeze.py"
chmod 0644 "$TARGET_DIR/dns_freeze.py"
