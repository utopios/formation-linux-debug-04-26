#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
INSTALL_DIR=/opt/hotcode

echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"

cat > "$INSTALL_DIR/hotcode.c" <<'EOF'
/* hotcode - binaire CPU-bound avec coupable cache.
 * noinline + volatile pour preserver les frontieres de fonctions dans perf.
 */
#include <stdio.h>

volatile const char *body_ptr = "POST /orders HTTP/1.1\r\nContent-Length: 42\r\n";

__attribute__((noinline))
unsigned long compute_fast(unsigned long x) {
    return x * 2654435761UL;
}

__attribute__((noinline))
unsigned long sha256_fake(const char *s) {
    unsigned long h = 5381;
    for (int i = 0; i < 200; i++) {
        for (int j = 0; s[j]; j++) {
            h = ((h << 5) + h) + (unsigned char)s[j];
        }
    }
    return h;
}

__attribute__((noinline))
unsigned long handle_request(int req_id) {
    const char *body = (const char *)body_ptr;
    unsigned long acc = compute_fast((unsigned long)req_id);
    for (int k = 0; k < 10; k++) {
        acc ^= sha256_fake(body);
    }
    return acc;
}

volatile unsigned long sink = 0;

int main(void) {
    int req_id = 0;
    /* Boucle infinie : tu controles la duree avec kill, comme un service. */
    while (1) {
        sink += handle_request(req_id++);
    }
    return 0;
}
EOF

gcc -O2 -g -fno-omit-frame-pointer -o "$INSTALL_DIR/hotcode" "$INSTALL_DIR/hotcode.c"

# FlameGraph (utilise par le TP)
if [ ! -d "$TARGET_HOME/FlameGraph" ]; then
    sudo -u "$TARGET_USER" git clone --depth 1 https://github.com/brendangregg/FlameGraph.git "$TARGET_HOME/FlameGraph"
fi

# Perf : autoriser sans sudo
echo 1 > /proc/sys/kernel/perf_event_paranoid 2>/dev/null || true

