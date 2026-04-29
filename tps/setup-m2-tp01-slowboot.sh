#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/slowboot
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"

cat > "$INSTALL_DIR/slowboot.c" <<'EOF'
/*
 * slowboot - service qui freeze au demarrage sur un recvfrom() UDP.
 *
 * On simule un appel a un service externe (par exemple, lookup d'un service
 * de configuration distant) en envoyant un datagramme UDP vers une IP non
 * routable, puis on attend la reponse. Le syscall coupable est recvfrom()
 * qui bloque indefiniment.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>

int main(void) {
    fprintf(stderr, "slowboot starting (PID %d)\n", getpid());
    fflush(stderr);

    int s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) { perror("socket"); return 1; }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(53);
    inet_pton(AF_INET, "10.255.255.1", &addr.sin_addr);

    const char *payload = "slowboot-config-request";

    fprintf(stderr, "sending request to config service 10.255.255.1:53 ...\n");
    fflush(stderr);
    sendto(s, payload, strlen(payload), 0, (struct sockaddr *)&addr, sizeof(addr));

    fprintf(stderr, "waiting for config service reply ...\n");
    fflush(stderr);

    /* Va bloquer indefiniment ici sur un recvfrom() UDP. */
    char buf[4096];
    struct sockaddr_in from;
    socklen_t fromlen = sizeof(from);
    ssize_t n = recvfrom(s, buf, sizeof(buf), 0, (struct sockaddr *)&from, &fromlen);

    fprintf(stderr, "got %ld bytes (this should never appear)\n", (long)n);

    for (;;) sleep(60);
    return 0;
}
EOF

gcc -O2 -g -o "$INSTALL_DIR/slowboot" "$INSTALL_DIR/slowboot.c"

cat > /etc/systemd/system/slowboot.service <<'EOF'
[Unit]
Description=slowboot - service qui freeze au demarrage (TP 1)

[Service]
Type=simple
ExecStart=/opt/slowboot/slowboot
StandardOutput=journal
StandardError=journal
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
