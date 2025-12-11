#!/bin/bash
echo "NODE"
hostname -I

echo "INFO"
redis-cli -p 26379 INFO sentinel