#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_DIR="$TARGET_HOME/demo-linux"

echo "[setup] preparation de $TARGET_DIR/hotloop"

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_DIR"

cat > "$TARGET_DIR/hotloop.c" <<'EOF'
#include <stdio.h>

/* Variable globale volatile : empeche gcc de propager la valeur de
 * payload dans work() (sinon constprop fusionne work avec main). */
volatile const char *payload_ptr = "une longue chaine a hacher";

/* noinline : empeche le compilateur d'inliner work() dans main(),
 * pour que perf report distingue les deux fonctions. */
__attribute__((noinline))
unsigned long work(const char *s) {
    unsigned long h = 0;
    for (int i = 0; s[i]; i++) {
        h = h * 131 + (unsigned char)s[i];
    }
    return h;
}

/* Sink global : empeche le compilateur d'eliminer ou de simplifier acc. */
volatile unsigned long sink = 0;

int main(void) {
    /* Boucle infinie : tu controles la duree avec kill, comme un service. */
    while (1) {
        sink += work((const char *)payload_ptr);
    }
    return 0;
}
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/hotloop.c"
sudo -u "$TARGET_USER" gcc -O2 -g -fno-omit-frame-pointer -fno-inline -o "$TARGET_DIR/hotloop" "$TARGET_DIR/hotloop.c"

# FlameGraph clone
if [ ! -d "$TARGET_HOME/FlameGraph" ]; then
    sudo -u "$TARGET_USER" git clone --depth 1 https://github.com/brendangregg/FlameGraph.git "$TARGET_HOME/FlameGraph"
fi

# Perf : autoriser sans sudo
echo 1 > /proc/sys/kernel/perf_event_paranoid 2>/dev/null || true
grep -q '^kernel.perf_event_paranoid' /etc/sysctl.d/99-training.conf 2>/dev/null || \
    echo 'kernel.perf_event_paranoid = 1' >> /etc/sysctl.d/99-training.conf


