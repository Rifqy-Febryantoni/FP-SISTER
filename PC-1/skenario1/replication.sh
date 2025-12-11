#!/bin/bash
echo "NODE"
hostname -I
echo "ROLE"
redis-cli INFO replication