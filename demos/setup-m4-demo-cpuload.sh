#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_DIR="$TARGET_HOME/demo-linux"

echo "[setup] preparation de $TARGET_DIR/cpuload.py"

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_DIR"

cat > "$TARGET_DIR/cpuload.py" <<'EOF'
#!/usr/bin/env python3
"""cpuload - generateur de charges variees pour la demo Module 4.

Quatre modes pedagogiques :
  - cpu-allcores  : N process CPU-bound (N = nproc) -> mpstat tous a 100%
  - cpu-onecore   : 1 process CPU-bound -> mpstat un seul coeur a 100%
  - cpu-overload  : 2*nproc process -> contention, nvcswch/s eleve
  - io-loop       : 1 process en read/write boucle -> cswch/s eleve

Usage :
  python3 cpuload.py <mode> [duree_secondes]

Default duree = 60s.
"""
import multiprocessing as mp
import os
import sys
import time

def cpu_burn(duration):
    """Boucle CPU pure : multiplications volatiles. Pas de syscall."""
    end = time.time() + duration
    x = 1.000001
    acc = 1.0
    while time.time() < end:
        for _ in range(100000):
            acc = acc * x + 1.0
            acc = acc / x - 0.5

def io_loop(duration):
    """Lectures/ecritures en boucle sur /dev/zero et /dev/null.
    Genere beaucoup de cswch/s (volontaires) car chaque syscall cede le CPU."""
    end = time.time() + duration
    buf = bytearray(4096)
    with open("/dev/zero", "rb") as zero, open("/dev/null", "wb") as null:
        while time.time() < end:
            for _ in range(1000):
                zero.readinto(buf)
                null.write(buf)
            time.sleep(0.001)  # cede le CPU = voluntary ctxt switch

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    mode = sys.argv[1]
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60

    nproc = os.cpu_count() or 2
    print(f"cpuload mode={mode} duration={duration}s nproc_detected={nproc} pid={os.getpid()}",
          flush=True)

    if mode == "cpu-allcores":
        nworkers = nproc
        target = cpu_burn
    elif mode == "cpu-onecore":
        nworkers = 1
        target = cpu_burn
    elif mode == "cpu-overload":
        nworkers = nproc * 2
        target = cpu_burn
    elif mode == "io-loop":
        nworkers = 1
        target = io_loop
    else:
        print(f"mode inconnu: {mode}")
        print(__doc__)
        sys.exit(1)

    print(f"-> spawning {nworkers} worker(s) target={target.__name__}", flush=True)

    procs = [mp.Process(target=target, args=(duration,)) for _ in range(nworkers)]
    for p in procs:
        p.start()
    for p in procs:
        p.join()
    print("done", flush=True)

if __name__ == "__main__":
    main()
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_DIR/cpuload.py"
chmod 0755 "$TARGET_DIR/cpuload.py"


