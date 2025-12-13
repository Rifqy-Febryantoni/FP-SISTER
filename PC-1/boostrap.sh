#!/bin/bash
set -e

echo "[*] Setting DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "[*] Installing packages for MASTER..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  redis redis-sentinel procps net-tools python3 python3-redis iproute2

echo "[*] Master bootstrap complete."
