FROM debian:stable-slim

# 1. INSTALLATION (Dilakukan saat Build Image)
# Kita gabungkan semua install di sini supaya image jadi satu lapis dan ringan
RUN apt-get update && apt-get install -y \
    redis-server \
    redis-sentinel \
    procps \
    net-tools \
    iputils-ping \
    nano \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root