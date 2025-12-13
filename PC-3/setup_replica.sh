#!/bin/bash
set -e

MASTER_IP="$1"

if [ -z "${MASTER_IP}" ]; then
  echo "Usage: $0 <MASTER_IP>"
  echo "Example: $0 192.168.122.10"
  exit 1
fi

echo "[*] Stopping old redis-server (if any)..."
systemctl stop redis-server 2>/dev/null || true
pkill redis-server 2>/dev/null || true

echo "[*] Writing /etc/redis/replica.conf ..."
cat > /etc/redis/replica.conf << CONF
bind 0.0.0.0
protected-mode no
port 6379
replicaof ${MASTER_IP} 6379
CONF

echo "[*] Starting redis-server as REPLICA of ${MASTER_IP}..."
redis-server /etc/redis/replica.conf &

sleep 1
echo
echo "[*] Replica replication info:"
redis-cli info replication | egrep "role|master_host|master_port" || true
