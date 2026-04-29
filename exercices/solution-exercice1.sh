#!/usr/bin/env bash
set -euo pipefail

if ! pgrep yes > /dev/null; then
    yes > /dev/null &
    sleep 1
fi
PID=$(pgrep yes | head -1)
echo "PID cible = $PID"

echo
echo "=== 1. cmdline ==="
tr '\0' ' ' < /proc/$PID/cmdline; echo

echo
echo "=== 2. exe ==="
readlink /proc/$PID/exe

echo
echo "=== 3. cwd ==="
readlink /proc/$PID/cwd

echo
echo "=== 4. user ==="
UID_REAL=$(awk '/^Uid:/ {print $2}' /proc/$PID/status)
echo "UID real = $UID_REAL"
USER_NAME=$(getent passwd $UID_REAL | cut -d: -f1)
echo "User = $USER_NAME"

echo
echo "=== 5. threads ==="
ls /proc/$PID/task/

echo
echo "=== 6. etat de chaque thread ==="
for t in /proc/$PID/task/*; do
    tid=$(basename $t)
    state=$(awk '/^State:/ {print $2, $3}' $t/status)
    echo "$tid -> $state"
done

echo
echo "=== 7. VmRSS et Threads ==="
grep -E '^(VmRSS|Threads):' /proc/$PID/status

echo
echo "=== 8. context switches ==="
grep -E '^(voluntary|nonvoluntary)_ctxt_switches:' /proc/$PID/status

kill $(pgrep yes) 2>/dev/null || true
