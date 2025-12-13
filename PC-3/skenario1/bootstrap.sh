#!/bin/bash
set -e

echo "[*] Setting DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "[*] Installing packages for REPLICA..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  redis redis-sentinel procps net-tools python3 python3-redis iproute2

echo "[*] Configuring network delay (10ms) for replica on eth0..."

# Hapus qdisc lama kalau ada, supaya tidak error "Exclusivity flag on"
tc qdisc del dev eth0 root 2>/dev/null || true

# Tambahkan delay 10ms untuk semua paket di eth0
tc qdisc add dev eth0 root netem delay 10ms

echo "[*] Current qdisc on eth0:"
tc qdisc show dev eth0

echo "[*] Replica bootstrap complete."
