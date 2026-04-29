#!/usr/bin/env bash
sudo systemctl restart slowboot.service
sudo systemctl status slowboot.service --no-pager | head -5
PID=$(systemctl show -p MainPID --value slowboot.service)
echo "PID slowboot = $PID"
cat /proc/$PID/wchan; echo

sudo timeout 3 strace -e trace=network -p $PID 2>&1 | tail -10 || true

sudo systemctl stop slowboot.service


ulimit -c unlimited

cat /proc/sys/kernel/core_pattern
ls -la /var/lib/coredumps/ | head -2

/opt/cruncher/cruncher 2>&1; echo "exit=$?"

sleep 1