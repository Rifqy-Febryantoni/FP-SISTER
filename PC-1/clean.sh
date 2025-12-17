#!/bin/bash
echo "Cleaning previous test"

# 1. Stop Services
service redis-server stop
pkill -f redis-sentinel
pkill -f redis-server

# 2. Ganti Config Lama 
cp /root/skenario3/redis.conf /etc/redis/redis.conf

# 3. Hapus Data Lama
rm -f /var/lib/redis/dump.rdb
rm -f /var/lib/redis/appendonly.aof
rm -f /var/lib/redis/nodes-6379.conf  
rm -f /var/lib/redis/nodes.conf       

echo "Start Service"
service redis-server start

# Tambahan: Pastikan database kosong di memori
sleep 2
redis-cli FLUSHALL
redis-cli CLUSTER RESET

echo "DONE"