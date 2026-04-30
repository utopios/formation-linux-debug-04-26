#!/usr/bin/env bash
set -euo pipefail

/opt/hotcode/hotcode &
HPID=$!
sleep 1
echo "PID hotcode = $HPID"

echo
echo "=== perf record ==="
perf record -F 99 -g -p $HPID -o /tmp/perf-hotcode.data -- sleep 10 2>&1 | tail -3

echo
echo "=== perf report (top symbols) ==="
perf report -i /tmp/perf-hotcode.data --stdio --no-children 2>&1 | grep -E "Overhead|^\s+[0-9]" | head -10