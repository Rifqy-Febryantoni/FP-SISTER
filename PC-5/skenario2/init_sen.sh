#!/bin/bash
set -e

echo "[*] Cleaning previous setup..."

# Stop services
systemctl stop redis-server 2>/dev/null || true
pkill -f redis-sentinel 2>/dev/null || true
pkill -f redis-server 2>/dev/null || true

# Remove old data
rm -f /var/lib/redis/dump.rdb
rm -f /var/lib/redis/appendonly.aof
rm -f /var/lib/redis/nodes.conf

echo "[*] Copying sentinel.conf to /etc/redis/sentinel.conf..."
cp sentinel.conf /etc/redis/sentinel.conf

echo "[*] Starting redis-sentinel..."
redis-sentinel /etc/redis/sentinel.conf 

echo "[*] Waiting for Sentinel to start..."
sleep 3

echo "[*] Redis Sentinel is running."