#!/bin/bash

M1="192.168.122.10"
M2="192.168.122.20"
M3="192.168.122.30"

R1="192.168.122.40"
R2="192.168.122.50"
R3="192.168.122.60"

TARGET=10000
INTERVAL=0.1 

echo "Sharding on Redis Cluster"

echo "Cleaning cluster..."
redis-cli -h $M1 -c flushall > /dev/null 2>&1
redis-cli -h $M2 -c flushall > /dev/null 2>&1
redis-cli -h $M3 -c flushall > /dev/null 2>&1
sleep 1

echo "Flooding master with $TARGET keys..."
redis-benchmark -h $M1 -p 6379 --cluster -t set -n $TARGET -r 1000000 -P 32 -q > /dev/null 2>&1
echo "Write done! Starting monitoring..."
echo ""

echo "Key replication monitoring..."
echo "    (Checking every $INTERVAL seconds)"
echo "Time (ms) | Total Replica | Remaining Lag | Status"

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
        printf " +%5d ms  |    %5d      |  -%5d   | catching up\n" $elapsed $CURRENT $LAG
    else
        printf " +%5d ms  |    %5d      |     0    | synced\n" $elapsed $CURRENT
        
        echo "Synced in ${elapsed} ms"
        break
    fi
    
    sleep $INTERVAL
done