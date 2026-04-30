#!/usr/bin/env bash

set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_DIR="$TARGET_HOME/demo-linux"

echo "[setup] preparation de $TARGET_DIR/*.bt"

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_DIR"

cat > "$TARGET_DIR/exec-top.bt" <<'EOF'
// Compte les execve par nom de commande.
tracepoint:syscalls:sys_enter_execve
{
    @[comm] = count();
}
EOF

cat > "$TARGET_DIR/read-hist.bt" <<'EOF'
// Histogramme de latence des lectures VFS.
// Lance avec : sudo bpftrace read-hist.bt   puis Ctrl-C pour arreter.
// Pas de bloc BEGIN ici : sur certaines combinaisons bpftrace<0.16 + kernel
// recent, BEGIN tente un uprobe sur /proc/self/exe et echoue avec
// "Could not resolve symbol: BEGIN_trigger".

kprobe:vfs_read
{
    @start[tid] = nsecs;
}

kretprobe:vfs_read
/@start[tid]/
{
    @us = hist((nsecs - @start[tid]) / 1000);
    delete(@start[tid]);
}
EOF

cat > "$TARGET_DIR/openat-by-comm.bt" <<'EOF'
// Top des fichiers ouverts par un process specifique (passer COMM en argument).
// Usage : sudo bpftrace openat-by-comm.bt bash   puis Ctrl-C pour arreter.
// Pas de BEGIN (voir note dans read-hist.bt).

tracepoint:syscalls:sys_enter_openat
/comm == str($1)/
{
    @[str(args->filename)] = count();
}
EOF

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR"

# Verifier la dispo BTF
if [ ! -f /sys/kernel/btf/vmlinux ]; then
    echo "[setup] WARN : /sys/kernel/btf/vmlinux absent. Certaines sondes peuvent echouer."
fi

# cat <<EOF

# [setup] OK : 3 scripts bpftrace dans $TARGET_DIR/.

# A executer :
#   sudo bpftrace $TARGET_DIR/exec-top.bt
#   sudo bpftrace $TARGET_DIR/read-hist.bt
#   sudo bpftrace $TARGET_DIR/openat-by-comm.bt bash
# EOF
