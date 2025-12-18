#!/bin/bash

SENTINEL_IP="192.168.122.40" 
SENTINEL_PORT="26379"
MASTER_NAME="mymaster"

echo "============================================="
echo "   SCENARIO 2: SENTINEL FAILOVER TEST        "
echo "   (Mengukur Waktu Downtime & Leader Election)"
echo "============================================="

# 1. CEK MASTER SAAT INI
echo "[1] Mengecek Master saat ini..."
CURRENT_MASTER=$(timeout 0.5 redis-cli -h $check_master -p 6379 set failover_test "ok" 2>&1)

if [ -z "$CURRENT_MASTER" ]; then
    echo "❌ Error: Tidak bisa connect ke Sentinel atau Master tidak ditemukan."
    exit 1
fi

echo "    👑 Master Aktif: $CURRENT_MASTER"
echo ""

# 2. PROSES FAILOVER (KILL MASTER)
echo "[2] MEMATIKAN MASTER ($CURRENT_MASTER)..."
echo "    Mengirim perintah 'DEBUG SEGFAULT' (Simulasi Crash)..."

# Kita kirim perintah crash ke Master di background
redis-cli -h $CURRENT_MASTER -p 6379 debug segfault > /dev/null 2>&1 &

echo "✅ Master dimatikan! Memulai Stopwatch Failover..."
echo ""

# 3. MONITORING FAILOVER (DETIK DEMI DETIK)
echo "[3] MENUNGGU LEADER ELECTION..."
echo "---------------------------------------------------------------"
echo " WAKTU (detik) | STATUS WRITE | STATUS MASTER DARI SENTINEL"
echo "---------------------------------------------------------------"

start_time=$(date +%s%N)
failover_done=false

while true; do
    # Hitung durasi berjalan
    now=$(date +%s%N)
    elapsed=$(echo "scale=2; ($now - $start_time) / 1000000000" | bc)

    # A. Cek Siapa Master Menurut Sentinel
    check_master=$(redis-cli -h $SENTINEL_IP -p $SENTINEL_PORT sentinel get-master-addr-by-name $MASTER_NAME | head -n 1)

    # B. Coba Tulis Data (Tes Availability)
    write_test=$(timeout 0.5 redis-cli -h $check_master -p 6379 set failover_test "ok" 2>&1)
    
    # C. Tentukan Status
    if [[ "$write_test" == "OK" ]]; then
        status_icon="✅ UP  "
    else
        status_icon="❌ DOWN"
        status_icon="$status_icon ($write_test)"
    fi

    # Tampilkan Log
    echo "   ${elapsed}s      |   $status_icon   | Master: $check_master"

    # D. Cek Apakah Failover Selesai?
    if [ "$check_master" != "$CURRENT_MASTER" ] && [ "$write_test" == "OK" ]; then
        echo "---------------------------------------------------------------"
        echo ""
        echo " FAILOVER SELESAI!"
        echo " Total Waktu Downtime: ${elapsed} detik"
        echo " Master Lama: $CURRENT_MASTER"
        echo " Master Baru: $check_master"
        echo ""
        echo " Analisa: Selama ${elapsed} detik, sistem menolak tulisan (Down)."
        echo "          Setelah itu, Replica $check_master dipromosikan jadi Master."
        break
    fi

    sleep 0.5
done
