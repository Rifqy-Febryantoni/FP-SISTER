#!/bin/bash

echo "REDIS SETUP"
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 1. INSTALLATION
echo "Installing Redis"
apt-get update
apt-get install -y redis redis-sentinel procps net-tools