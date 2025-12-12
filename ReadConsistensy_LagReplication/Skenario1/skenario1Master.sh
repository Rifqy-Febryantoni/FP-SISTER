#!/bin/sh

redis-cli flushall

echo "1. Membuat file berisi 1000 perintah SET..."
rm -f data.txt
for i in (1..1000); do
    echo "SET key:$1 data_$1" >> data.txt
done

cat data.txt | redis-cli --pipe

echo "~\~E SELESAI! cek jumlah data:"
redis-cli dbsize