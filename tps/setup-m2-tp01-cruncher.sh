#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/cruncher
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"

cat > "$INSTALL_DIR/cruncher.c" <<'EOF'
/*
 * cruncher - segfault deterministe par dereferencement de pointeur invalide.
 *
 * On ecrit dans un pointeur volontairement faux pour garantir un SIGSEGV
 * propre et reproductible (vs. un acces hors borne tableau qui peut tomber
 * dans le padding glibc et passer inapercu).
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

typedef struct {
    int key;
    int value;
    char label[64];
} item_t;

static void process_item(item_t *item, int key) {
    item->key = key;
    item->value = key * 2 + 1;
    snprintf(item->label, sizeof(item->label), "item-%d", key);
}

int main(void) {
    fprintf(stderr, "cruncher starting (PID %d)\n", getpid());

    /* Phase de "travail normal" pour le suspense */
    for (int round = 0; round < 3; round++) {
        sleep(1);
        fprintf(stderr, "round %d ok\n", round);
    }

    /* Bug volontaire : on processe un pointeur NULL au 4eme tour
     * (par exemple, lookup dans une cache qui retourne NULL et
     * dont le code ne verifie pas le retour avant de dereferencer). */
    fprintf(stderr, "round 3: looking up next item ...\n");

    item_t *items = calloc(8, sizeof(item_t));
    if (!items) return 1;
    for (int i = 0; i < 8; i++) {
        process_item(&items[i], i);
    }

    /* Le bug : on suppose que cache_get(99) retourne un item valide,
     * mais il retourne NULL. process_item dereference -> SIGSEGV. */
    item_t *bad = NULL;  /* simule un cache miss non verifie */
    process_item(bad, 99);

    fprintf(stderr, "cruncher done (this should never appear)\n");
    free(items);
    return 0;
}
EOF

gcc -O0 -g -fno-omit-frame-pointer -o "$INSTALL_DIR/cruncher" "$INSTALL_DIR/cruncher.c"

# Activer les core dumps systeme
mkdir -p /var/lib/coredumps
chmod 1777 /var/lib/coredumps  # sticky bit + monde-ecrivable, sinon les process user ne peuvent pas y ecrire
echo '/var/lib/coredumps/core.%e.%p.%t' > /proc/sys/kernel/core_pattern 2>/dev/null || true
# Persister le core_pattern apres reboot
echo 'kernel.core_pattern = /var/lib/coredumps/core.%e.%p.%t' > /etc/sysctl.d/99-coredumps-pattern.conf
sysctl -p /etc/sysctl.d/99-coredumps-pattern.conf >/dev/null 2>&1 || true

cat > /etc/security/limits.d/99-coredumps.conf <<'EOF'
*               soft    core            unlimited
*               hard    core            unlimited
EOF


