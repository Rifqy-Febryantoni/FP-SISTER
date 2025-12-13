#!/bin/bash

# Fungsi untuk mengubah IP menjadi Nama PC (Agar output cantik)
get_pc_name() {
    case $1 in
        "192.168.122.10") echo "PC-1" ;;
        "192.168.122.20") echo "PC-2" ;;
        "192.168.122.30") echo "PC-3" ;;
        "192.168.122.40") echo "PC-4" ;;
        "192.168.122.50") echo "PC-5" ;;
        "192.168.122.60") echo "PC-6" ;;
        *) echo "Unknown-PC" ;;
    esac
}

echo "--- MULAI TESTING DARI CLIENT (PC-7) ---"

# Target sembarang untuk entry point
TARGET_IP="192.168.122.10"

echo "Menyimpan 10.000 data ke Cluster..."
for i in {0..10000}; do
  # -c (cluster mode) wajib agar PC-7 mau dilempar-lempar antar node
  redis-cli -c -h $TARGET_IP set key$i "data_dari_client_$i" > /dev/null
  
  if (( $i % 2000 == 0 )); then
    echo "Progress: tersimpan key$i..."
  fi
done
echo "--- SELESAI MENYIMPAN ---"
echo ""

echo "--- CEK DISTRIBUSI DATA & REPLIKASI ---"

# Ambil peta cluster (siapa master siapa slave) dari node 10
# Format output cluster nodes: <ID> <IP:Port> <Flags> <MasterID> ...
CLUSTER_INFO=$(redis-cli -h 192.168.122.10 cluster nodes)

# --- BAGIAN MASTER ---
echo ">> MASTER NODES (Utama):"
for IP in 192.168.122.10 192.168.122.20 192.168.122.30; do
    NAME=$(get_pc_name $IP)
    # Langsung cek DBSIZE karena Master pasti bisa read/write
    COUNT=$(redis-cli -c -h $IP DBSIZE)
    echo "   [$NAME] $IP memegang : $COUNT keys"
done

echo ""

# --- BAGIAN SLAVE ---
echo ">> SLAVE/REPLICA NODES (Backup):"
for IP in 192.168.122.40 192.168.122.50 192.168.122.60; do
    NAME=$(get_pc_name $IP)
    
    # 1. Cari ID Master dari output CLUSTER_INFO
    # Grep baris IP Slave -> Ambil kolom ke-4 (Master ID)
    MY_MASTER_ID=$(echo "$CLUSTER_INFO" | grep $IP | awk '{print $4}')
    
    # 2. Cari IP Master berdasarkan ID Master tadi
    # Grep baris yang diawali Master ID -> Ambil kolom ke-2 (IP:Port) -> Bersihkan Port
    MASTER_IP_RAW=$(echo "$CLUSTER_INFO" | grep "^$MY_MASTER_ID" | awk '{print $2}')
    MASTER_IP=${MASTER_IP_RAW%:*} # Hapus port :6379
    MASTER_NAME=$(get_pc_name $MASTER_IP)

    # 3. Cek DBSIZE 
    # Kita kirim perintah READONLY dulu, baru DBSIZE
    COUNT=$(redis-cli -c -h $IP <<< "READONLY
DBSIZE" | tail -n 1)

    echo "   [$NAME] $IP (Slave dari $MASTER_NAME) memegang : $COUNT keys"
done

echo ""
echo "--- TESTING SELESAI ---"