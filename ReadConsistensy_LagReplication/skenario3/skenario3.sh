#!/bin/bash

M1="192.168.122.10"
M2="192.168.122.20"
M3="192.168.122.30"

R1="192.168.122.40"
R2="192.168.122.50"
R3="192.168.122.60"

TARGET=10000
INTERVAL=0.1 

echo "============================================="
echo "   SCENARIO 3: HIGH-RES LAG MONITORING       "
echo "============================================="

echo "[1] Membersihkan Cluster..."
redis-cli -h $M1 -c flushall > /dev/null 2>&1
redis-cli -h $M2 -c flushall > /dev/null 2>&1
redis-cli -h $M3 -c flushall > /dev/null 2>&1
sleep 1

echo "[2] BOM DATA KE MASTER ($TARGET keys)..."
redis-benchmark -h $M1 -p 6379 --cluster -t set -n $TARGET -r 1000000 -P 32 -q > /dev/null 2>&1
echo "✅ Write Selesai! Langsung masuk mode pantau..."
echo ""

echo "[3] LIVE MONITORING REPLIKASI..."
echo "    (Mengecek setiap $INTERVAL detik...)"
echo "----------------------------------------------------------------"
echo " WAKTU (ms) | TOTAL REPLICA |  SISA LAG  | STATUS"
echo "----------------------------------------------------------------"

start_mon=$(date +%s%N)

while true; do
    c1=$(redis-cli -h $R1 dbsize)
    c2=$(redis-cli -h $R2 dbsize)
    c3=$(redis-cli -h $R3 dbsize)
    
    CURRENT=$((c1 + c2 + c3))
    
    LAG=$((TARGET - CURRENT))
    if [ "$LAG" -lt 0 ]; then LAG=0; fi

    now=$(date +%s%N)
    elapsed=$(( (now - start_mon) / 1000000 ))
    
    if [ "$LAG" -gt 0 ]; then
        printf " +%5d ms  |    %5d      |  -%5d   | ❌ MENGEJAR...\n" $elapsed $CURRENT $LAG
    else
        printf " +%5d ms  |    %5d      |     0    | ✅ SINKRON!\n" $elapsed $CURRENT
        
        echo "----------------------------------------------------------------"
        echo "KESIMPULAN:"
        echo "Total waktu sinkronisasi: ${elapsed} ms"
        break
    fi
    
    sleep $INTERVAL
done