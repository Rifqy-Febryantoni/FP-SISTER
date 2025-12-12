#!/bin/bash

#(Optional)Tambahka delay terhadap data yang masuk dan keluar yaitu 500 ms agar terlihat lag replication (disetiap node replica)
#tc qdisc add dev eth0 root netem delay 500ms


TARGET=1000
echo "--- MONITORING SINYAL MASUK ---"
echo "Menunggu data merambat dari Master..."


while true; do
    CURRENT=$(redis-cli dbsize)

    MISSING=$((TARGET - CURRENT))

    echo "Data Masuk: $CURRENT | Belum Sinkron (Lag): $MISSING"

    if [ "$CURRENT" -ge "$TARGET"]; then
        echo "~\~E SINKRONISASI SELESAI! (Eventual Consistency Tercapai)"
        break
    fi

    sleep 0.5
done