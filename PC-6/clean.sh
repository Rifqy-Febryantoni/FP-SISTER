#!/bin/bash
echo "Cleaning previous test"

# 1. Stop Services
service redis-server stop
pkill -f redis-sentinel
pkill -f redis-server

# 2. Replace redis config
cp skenario3/redis.conf /etc/redis/redis.conf

# 3. Remove old data
rm -f /var/lib/redis/dump.rdb
rm -f /var/lib/redis/appendonly.aof
rm -f /var/lib/redis/nodes.conf

echo "Start Service"
service redis-server start

echo "DONE"