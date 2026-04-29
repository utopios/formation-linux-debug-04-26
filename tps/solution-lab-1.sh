#!/usr/bin/env bash
set +e

PID=$(systemctl show -p MainPID --value billingd.service)
if [ -z "$PID" ] || [ "$PID" -eq 0 ]; then
    echo "billingd n'est pas demarre. Lance d'abord setup-lab-jour1-billingd.sh"
    exit 1
fi
echo "PID billingd = $PID"
echo "=== fiche identite (/proc/$PID/status) ==="

echo "=== threads et leurs etats ==="
for t in /proc/$PID/task/*; do
    tid=$(basename $t)
    state=$(awk '/^State:/ {print $2, $3}' $t/status 2>/dev/null)
    name=$(awk '/^Name:/ {print $2}' $t/status 2>/dev/null)
    echo "TID $tid name=$name state=$state"
done

# echo
# echo "========================================"
# echo "  PISTE A - Ticket 4823 : memoire (M3)"
# echo "========================================"

# echo
# echo "=== mesure 1 (T0) ==="
# T0=$(date +%T)
# RSS_T0=$(awk '/^VmRSS:/ {print $2}' /proc/$PID/status)
# RSSANON_T0=$(awk '/^RssAnon:/ {print $2}' /proc/$PID/status)
# echo "$T0 VmRSS=$RSS_T0 kB RssAnon=$RSSANON_T0 kB"

# echo
# echo "=== pmap T0 (top 5 zones) ==="
# sudo pmap -x $PID > /tmp/lab-pmap-t0.txt
# sort -k2 -n -r /tmp/lab-pmap-t0.txt | head -5

# sleep 30

# echo
# echo "=== mesure 2 (T+30s) ==="
# T1=$(date +%T)
# RSS_T1=$(awk '/^VmRSS:/ {print $2}' /proc/$PID/status)
# RSSANON_T1=$(awk '/^RssAnon:/ {print $2}' /proc/$PID/status)
# echo "$T1 VmRSS=$RSS_T1 kB RssAnon=$RSSANON_T1 kB"

# DELTA_RSS=$(( RSS_T1 - RSS_T0 ))
# DELTA_ANON=$(( RSSANON_T1 - RSSANON_T0 ))
# echo "delta VmRSS = $DELTA_RSS kB en 30s"
# echo "delta RssAnon = $DELTA_ANON kB en 30s"

# echo
# echo "=== pmap T+30s (top 5 zones) ==="
# sudo pmap -x $PID > /tmp/lab-pmap-t1.txt
# sort -k2 -n -r /tmp/lab-pmap-t1.txt | head -5

# echo
# echo "=== diff zones (qui grossit ?) ==="
# diff <(sort -k2 -n -r /tmp/lab-pmap-t0.txt | head -5) \
#      <(sort -k2 -n -r /tmp/lab-pmap-t1.txt | head -5)

# cat /proc/$PID/oom_score

echo
echo "========================================"
echo "  PISTE B - Ticket 4822 : freeze (M2)"
echo "========================================"

echo
echo "=== piles noyau de chaque thread ==="
for t in /proc/$PID/task/*; do
    tid=$(basename $t)
    state=$(awk '/^State:/ {print $2}' $t/status)
    stack=$(sudo cat $t/stack 2>/dev/null | head -2 | tr '\n' '|')
    echo "TID $tid state=$state stack=$stack"
done

SUSPECT_TID=""
for t in /proc/$PID/task/*; do
    tid=$(basename $t)
    if sudo cat $t/stack 2>/dev/null | grep -qE 'connect|inet_csk|tcp_wait'; then
        SUSPECT_TID=$tid
        break
    fi
done

if [ -n "$SUSPECT_TID" ]; then
    echo
    echo "=== thread suspect identifie : TID $SUSPECT_TID ==="
    echo "--- stack complete ---"
    sudo cat /proc/$SUSPECT_TID/stack
    echo "--- syscall en cours ---"
    sudo cat /proc/$SUSPECT_TID/syscall

    echo
    echo "=== strace sur ce thread (5s, filtre network) ==="
    sudo timeout 5 strace -e trace=network -p $SUSPECT_TID 2>&1 | tail -10
fi

# echo
# echo "=== sockets/connexions du process ==="
# sudo ss -tnp 2>/dev/null | grep "pid=$PID" | head
# echo
# sudo lsof -p $PID -i 2>/dev/null | head

# echo
# echo "=== ip route get vers la cible suspecte ==="
# ip route get 10.255.255.5 2>&1
# echo
# timeout 3 nc -zv 10.255.255.5 443 2>&1; echo "exit=$?"

echo
echo "========================================"
echo "  PISTE C - Ticket 4821 : relances (M1+M3)"
echo "========================================"

echo
echo "=== historique systemd des derniers signaux ==="
sudo journalctl -u billingd --since "2 hours ago" 2>/dev/null | grep -E 'Started|Stopped|Failed|Killed|signal|OOM' | tail -10

echo
echo "=== systemctl show : metriques ==="
sudo systemctl show billingd | grep -E '^(NRestarts|Result|ExecMainStatus|MainPID)='

echo
echo "=== dmesg : trace OOM ==="
sudo dmesg -T | grep -iE 'killed process|out of memory|Memory cgroup' | tail -5

echo
echo "=== zombies (multiples passages pour les attraper) ==="
for i in 1 2 3; do
    Z=$(ps -eo pid,ppid,stat,comm | awk -v p="$PID" '$3 ~ /Z/ && $2 == p {count++} END {print count+0}')
    echo "passage $i : $Z zombies fils de billingd"
    sleep 1
done