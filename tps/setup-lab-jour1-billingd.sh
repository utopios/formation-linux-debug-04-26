#!/usr/bin/env bash
# setup-lab-jour1-billingd.sh
# Lab Jour 1 - service billingd avec 3 incidents simultanes (M1+M2+M3).
# Apt requis : python3 procps sysstat strace ltrace
# IMPORTANT : ce script doit etre lance avec sudo. VM ou serveur dedie.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[setup] Lance ce script avec sudo." >&2
    exit 1
fi

INSTALL_DIR=/opt/billingd
echo "[setup] preparation de $INSTALL_DIR"

install -d -m 0755 "$INSTALL_DIR"

cat > "$INSTALL_DIR/billingd.py" <<'EOF'
#!/usr/bin/env python3
"""billingd - demon de facturation avec 3 incidents simultanes.

Conception pedagogique :
  - thread accounting  : fuite memoire (croissance ~12 Mo/15s, OOM en quelques min)
  - thread sync_remote : connect TCP vers IP non-routable (freeze permanent du thread)
  - thread cleanup     : fork+sleep sans wait (zombies ephemeres)

L'objectif est qu'un apprenant ne puisse PAS conclure correctement en regardant
seulement un outil : il doit croiser /proc, strace, pmap, ps pour reconstituer
les 3 mecanismes.
"""
import os
import socket
import subprocess
import threading
import time

# -----------------------------------------------------------------------------
# Thread 1 : accounting (fuite memoire deterministe)
# -----------------------------------------------------------------------------
_invoice_cache = []

def thread_accounting():
    """Simule un cache de factures qui ne purge jamais."""
    counter = 0
    while True:
        counter += 1
        # Chaque "facture" pese 12 Mo de payload (faux PDF en memoire)
        payload = bytearray(12 * 1024 * 1024)
        _invoice_cache.append((counter, payload))
        time.sleep(15)

# -----------------------------------------------------------------------------
# Thread 2 : sync_remote (connect TCP qui ne reviendra jamais)
# -----------------------------------------------------------------------------
def thread_sync_remote():
    """Simule un appel periodique a un load balancer interne devenu injoignable."""
    while True:
        try:
            # 10.255.255.5 est dans le bloc 10.0.0.0/8 mais l'IP precise n'a pas
            # de route - le connect SYN ne recoit jamais de reponse, le syscall
            # bloque jusqu'au timeout TCP par defaut (~2 min) puis on relance.
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(None)  # blocage volontaire, pas de timeout applicatif
            s.connect(("10.255.255.5", 443))
            s.close()
        except Exception:
            pass
        time.sleep(5)

# -----------------------------------------------------------------------------
# Thread 3 : cleanup (fork sans wait => zombies)
# -----------------------------------------------------------------------------
def thread_cleanup():
    """Lance des sous-process /bin/true sans collecter leur exit code.

    En theorie subprocess.Popen sans .wait() garde la reference; le GC python
    appellera os.waitpid eventuellement. On force le scenario en gardant les
    references vivantes jusqu'a ce qu'on ait genere quelques zombies.
    """
    children = []
    while True:
        # fork via subprocess sans wait : les enfants finissent immediatement
        # et restent en defunct tant que le parent n'a pas reclame leur status.
        p = subprocess.Popen(["/bin/true"])
        children.append(p)
        # On garde les 50 derniers Popen vivants (donc pas de wait via GC)
        if len(children) > 50:
            # On laisse partir doucement les plus anciens : nettoyage trop
            # agressif rendrait les zombies trop ephemeres pour etre vus.
            old = children.pop(0)
            try:
                old.poll()  # collecte non-bloquante, peut laisser le zombie un instant
            except Exception:
                pass
        time.sleep(2)

# -----------------------------------------------------------------------------
# Main : lance les 3 threads et boucle pour rester actif
# -----------------------------------------------------------------------------
def main():
    print(f"billingd starting (PID {os.getpid()})", flush=True)
    threads = [
        threading.Thread(target=thread_accounting, name="accounting", daemon=True),
        threading.Thread(target=thread_sync_remote, name="sync_remote", daemon=True),
        threading.Thread(target=thread_cleanup, name="cleanup", daemon=True),
    ]
    for t in threads:
        t.start()
        print(f"thread started: {t.name}", flush=True)

    # Le main thread reste vivant en imprimant un heartbeat
    counter = 0
    while True:
        counter += 1
        cache_mb = len(_invoice_cache) * 12
        print(f"heartbeat #{counter} cache={cache_mb}MB threads_alive={sum(t.is_alive() for t in threads)}",
              flush=True)
        time.sleep(10)

if __name__ == "__main__":
    main()
EOF

chmod 0755 "$INSTALL_DIR/billingd.py"

# -----------------------------------------------------------------------------
# Service systemd avec Restart=on-failure pour reproduire la spirale de relance
# -----------------------------------------------------------------------------
cat > /etc/systemd/system/billingd.service <<'EOF'
[Unit]
Description=billingd - demon de facturation interne (Lab Jour 1)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/billingd/billingd.py
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5
# Pas de MemoryMax volontaire : on veut que l'OOM kernel agisse.

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# -----------------------------------------------------------------------------
# Core dumps : configurer un chemin lisible pour le ticket 4821
# -----------------------------------------------------------------------------
mkdir -p /var/lib/coredumps
chmod 1777 /var/lib/coredumps
echo '/var/lib/coredumps/core.%e.%p.%t' > /proc/sys/kernel/core_pattern 2>/dev/null || true
echo 'kernel.core_pattern = /var/lib/coredumps/core.%e.%p.%t' > /etc/sysctl.d/99-coredumps-billingd.conf
sysctl -p /etc/sysctl.d/99-coredumps-billingd.conf >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# Swap dedie au lab : 1 Go, pour observer si/so avant l'OOM
# -----------------------------------------------------------------------------
if ! swapon --show | grep -q '/swapfile-billingd'; then
    fallocate -l 1G /swapfile-billingd
    chmod 600 /swapfile-billingd
    mkswap /swapfile-billingd > /dev/null
    swapon /swapfile-billingd
    grep -q '/swapfile-billingd' /etc/fstab || echo '/swapfile-billingd none swap sw 0 0' >> /etc/fstab
fi

# Demarrer immediatement pour que l'apprenant arrive sur un systeme deja en incident
systemctl enable billingd.service >/dev/null 2>&1 || true
systemctl restart billingd.service


