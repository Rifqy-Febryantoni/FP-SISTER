#!/bin/bash

# Optional: Add 500ms delay to simulate replication lag (on each replica node)

TARGET=1000
echo "--- Checking incoming data ---"
echo "Waiting for data from master..."

while true; do
    CURRENT=$(redis-cli dbsize)

    MISSING=$((TARGET - CURRENT))

    echo "Got: $CURRENT | Still lagging: $MISSING"

    if [ "$CURRENT" -ge "$TARGET" ]; then
        echo "Synced all $TARGET keys"
        break
    fi

    sleep 0.5
done