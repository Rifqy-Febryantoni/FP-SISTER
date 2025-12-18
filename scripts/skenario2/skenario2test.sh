#!/bin/bash

SENTINEL_IP="192.168.122.40" 
SENTINEL_PORT="26379"
MASTER_NAME="mymaster"

echo "============================================="
echo "   SCENARIO 2: SENTINEL FAILOVER TEST        "
echo "============================================="

# 1. CEK MASTER SAAT INI
echo "[1] Mengecek Master saat ini..."

# KITA TANYA SENTINEL, BUKAN COBA NULIS
CURRENT_MASTER=$(redis-cli -h $SENTINEL_IP -p $SENTINEL_PORT sentinel get-master-addr-by-name $MASTER_NAME | head -n 1)

if [ -z "$CURRENT_MASTER" ]; then
    echo "❌ Error: Sentinel tidak merespon atau Master tidak ditemukan."
    echo "   Cek apakah Sentinel di $SENTINEL_IP sudah jalan?"
    exit 1
fi

echo "   Master Aktif: $CURRENT_MASTER"
echo ""

# 2. PROSES FAILOVER (KILL MASTER)
echo "[2] MEMATIKAN MASTER ($CURRENT_MASTER)..."
timeout 1 redis-cli -h $CURRENT_MASTER -p 6379 shutdown nosave > /dev/null 2>&1 &

echo "✅ Master dimatikan! Memulai Stopwatch Failover..."
echo ""

# 3. MONITORING FAILOVER
echo "[3] MENUNGGU LEADER ELECTION..."
echo "---------------------------------------------------------------"
echo " WAKTU (detik) | STATUS WRITE | STATUS MASTER DARI SENTINEL"
echo "---------------------------------------------------------------"

start_time=$(date +%s%N)

while true; do
    # Hitung durasi
    now=$(date +%s%N)
    elapsed=$(awk -v s=$start_time -v n=$now 'BEGIN {printf "%.2f", (n - s) / 1000000000}')

    # A. Cek Siapa Master Menurut Sentinel
    check_master=$(redis-cli -h $SENTINEL_IP -p $SENTINEL_PORT sentinel get-master-addr-by-name $MASTER_NAME | head -n 1)

    # B. Coba Tulis Data
    if [ -z "$check_master" ]; then
        write_test="NO_MASTER_FOUND"
    else
        write_test=$(timeout 0.5 redis-cli -h $check_master -p 6379 set failover_test "ok" 2>&1)
    fi
    
    # C. Tentukan Status
    if [[ "$write_test" == *"OK"* ]]; then
        status_icon="✅ UP  "
    else
        status_icon="❌ DOWN"
    fi
    
    echo "   ${elapsed}s      |   $status_icon   | Master: $check_master"

    # D. Cek Apakah Failover Selesai?
    if [ "$check_master" != "$CURRENT_MASTER" ] && [[ "$write_test" == *"OK"* ]]; then
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
    
    # E. Timeout Safety
    is_timeout=$(awk -v e=$elapsed 'BEGIN {print (e > 60) ? 1 : 0}')
    if [ "$is_timeout" -eq 1 ]; then
        echo "⛔ TIME OUT: Sudah 60 detik. Cek config sentinel!"
        break
    fi

    sleep 0.5
done
