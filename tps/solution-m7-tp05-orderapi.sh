#!/usr/bin/env bash
set -euo pipefail

sudo systemctl restart orderapi.service
sleep 3

echo
echo "=== healthcheck ==="
curl -s http://localhost:8080/health

echo
echo "=== latence baseline (3 mesures) ==="
for i in 1 2 3; do
    start=$(date +%s%N)
    curl -s http://localhost:8080/orders >/dev/null
    end=$(date +%s%N)
    echo "latency_ms=$(( (end - start) / 1000000 ))"
done

echo
echo "=== declenchement de l'incident ==="
sudo systemctl start orderapi-flock.service &
FLOCK_PID=$!
sleep 3

echo
echo "=== latence sous incident (3 mesures, max 5s) ==="
for i in 1 2 3; do
    start=$(date +%s%N)
    curl -s --max-time 5 http://localhost:8080/orders >/dev/null 2>&1
    end=$(date +%s%N)
    echo "latency_ms=$(( (end - start) / 1000000 ))"
done

echo
echo "=== USE : CPU ==="
top -b -n 1 | head -10

echo
echo "=== USE : memoire ==="
free -h

echo
echo "=== USE : I/O ==="
iostat -xz 1 2 | tail -10

echo
echo "=== USE : reseau ==="
ss -s

ORDERAPI_PID=$(systemctl show -p MainPID --value orderapi.service)
echo
echo "PID orderapi = $ORDERAPI_PID"

echo
echo "=== bpftrace : histogramme vfs_read pour python3 ==="
sudo timeout 8 bpftrace -e '
    kprobe:vfs_read /pid == '$ORDERAPI_PID'/ { @start[tid] = nsecs; }
    kretprobe:vfs_read /@start[tid]/
    { @ms = hist((nsecs - @start[tid]) / 1000000); delete(@start[tid]); }
' 2>&1 &
BPFTRACE_PID=$!
sleep 1

for i in 1 2 3 4 5; do
    curl -s --max-time 5 http://localhost:8080/orders >/dev/null 2>&1 &
done
wait

wait $BPFTRACE_PID 2>/dev/null || true

echo
echo "=== lsof sur cache.json ==="
sudo lsof /var/lib/orderapi/cache.json 2>/dev/null | head

echo
echo "=== status orderapi-flock ==="
sudo systemctl status orderapi-flock.service --no-pager | head -5

sudo systemctl stop orderapi.service orderapi-flock.service 2>/dev/null || true
kill $FLOCK_PID 2>/dev/null || true
