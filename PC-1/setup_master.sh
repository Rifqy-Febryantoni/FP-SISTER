#!/bin/bash
set -e

# Ambil IP master hanya untuk info
MASTER_IP=$(ip -4 addr show eth0 | awk '/inet /{print $2}' | cut -d/ -f1)

echo "[*] Stopping old redis-server (if any)..."
systemctl stop redis-server 2>/dev/null || true
pkill redis-server 2>/dev/null || true

echo "[*] Writing /etc/redis/master.conf ..."
cat > /etc/redis/master.conf << 'CONF'
bind 0.0.0.0
protected-mode no
port 6379
appendonly no
CONF

echo "[*] Starting redis-server as MASTER..."
redis-server /etc/redis/master.conf &

sleep 1
echo
echo "[*] Master replication info:"
redis-cli info replication | egrep "role|connected_slaves" || true
echo
echo "Master is running at ${MASTER_IP}:6379"
