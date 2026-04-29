#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_DIR="$TARGET_HOME/demo-linux"

echo "[setup] preparation de $TARGET_DIR/hello"

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_DIR"

cat > "$TARGET_DIR/hello.c" <<'EOF'
#include <stdio.h>
#include <unistd.h>

int main(void) {
    printf("Bonjour, monde\n");
    sleep(2);
    return 0;
}
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/hello.c"
sudo -u "$TARGET_USER" gcc -O2 -g -o "$TARGET_DIR/hello" "$TARGET_DIR/hello.c"

cat <<EOF

[setup] OK : $TARGET_DIR/hello cree.