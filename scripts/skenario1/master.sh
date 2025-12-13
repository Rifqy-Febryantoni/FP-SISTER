#!/bin/sh

redis-cli flushall

echo "Generating 1000 SET commands..."
rm -f data.txt
for i in $(seq 1 1000); do
    echo "SET key:$i data_$i" >> data.txt
done

cat data.txt | redis-cli --pipe

echo "Data count:"
redis-cli dbsize