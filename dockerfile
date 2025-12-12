FROM debian:stable-slim

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