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

echo "[*] Copying redis.conf to /etc/redis/redis.conf..."
cp redis.conf /etc/redis/redis.conf

echo "[*] Starting redis-server..."
redis-server /etc/redis/redis.conf

echo "[*] Waiting for Redis to start..."
sleep 2

echo "[*] Redis status:"
redis-cli INFO replication | grep -E "role|master_host|master_port" || true

echo "[*] Redis is running. Replica ready."