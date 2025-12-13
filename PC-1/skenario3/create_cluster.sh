#!/bin/bash
# Redis Cluster Init
# 
#   PRIMARY MASTERS (3):
#     - PC-1 (192.168.122.10:6379) - Hash Slots: 0-5460
#     - PC-3 (192.168.122.30:6379) - Hash Slots: 5461-10922
#     - PC-5 (192.168.122.50:6379) - Hash Slots: 10923-16383
#
#   REPLICA NODES (3):
#     - PC-2 (192.168.122.20:6379) - Replica of PC-1
#     - PC-4 (192.168.122.40:6379) - Replica of PC-3
#     - PC-6 (192.168.122.60:6379) - Replica of PC-5


echo "Creating Redis Cluster..."
echo "Masters: PC-1 (slots 0-5460), PC-3 (slots 5461-10922), PC-5 (slots 10923-16383)"
echo "Replicas: PC-2 to PC-1, PC-4 to PC-3, PC-6 to PC-5"

echo "yes" | redis-cli --cluster create \
  192.168.122.10:6379 \
  192.168.122.20:6379 \
  192.168.122.30:6379 \
  192.168.122.40:6379 \
  192.168.122.50:6379 \
  192.168.122.60:6379 \
  --cluster-replicas 1

sleep 2

echo ""
echo "CLUSTER STATUS:"
redis-cli -h 192.168.122.10 cluster nodes