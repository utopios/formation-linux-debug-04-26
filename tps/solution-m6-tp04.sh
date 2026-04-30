#!/usr/bin/env bash
set -euo pipefail

echo
echo "=== demarrage logger + archiver ==="
sudo systemctl restart logger.service archiver.service
sleep 3

echo
echo "=== iostat -xz 1 5 ==="
iostat -xz 1 5 | tail -15

echo
echo "=== iotop -oPbk -n 2 ==="
sudo iotop -oPbk -n 2 -d 1 | tail -15

LOGGER_PID=$(systemctl show -p MainPID --value logger.service)
ARCHIVER_PID=$(systemctl show -p MainPID --value archiver.service)

echo
echo "=== strace logger 2s (write/fsync) ==="
sudo timeout 2 strace -c -e trace=write,fsync -p $LOGGER_PID 2>&1 | tail -10

echo
echo "=== strace archiver 2s (write/fsync) ==="
sudo timeout 2 strace -c -e trace=write,fsync -p $ARCHIVER_PID 2>&1 | tail -10

sudo systemctl stop logger.service archiver.service 2>/dev/null || true
