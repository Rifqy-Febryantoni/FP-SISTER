#!/bin/bash

echo "Creating Redis Cluster..."

echo "yes" | redis-cli --cluster create \
  192.168.122.10:6379 \
  192.168.122.20:6379 \
  192.168.122.30:6379 \
  192.168.122.40:6379 \
  192.168.122.50:6379 \
  192.168.122.60:6379 \
  --cluster-replicas 1

echo "Waiting for cluster"
sleep 10

echo ""
echo "CLUSTER TOPOLOGY"

# Logic:
# - Simpan semua mapping ID -> IP ke dalam memory array
# - Pisahkan mana baris Master dan mana baris Slave
# - Print Master
# - Print Slave sambil mencocokkan Master ID dengan IP aslinya

redis-cli -h 192.168.122.10 cluster nodes | sort -k2 | awk '
{
    # $1=ID, $2=IP:Port@Bus, $3=Flags, $4=MasterID
    
    # Bersihkan format IP (hilangkan @16379)
    split($2, addr, "@");
    ip_port = addr[1];

    # Simpan mapping ID ke IP dalam array
    id_map[$1] = ip_port;

    # Simpan baris lengkap ke array baris
    lines[NR] = $0;
}
END {
    # Cetak Daftar Master Dulu
    print "------------------------------------------------"
    print "TYPE    | NODE IP             | SLOT / STATUS   "
    print "------------------------------------------------"
    
    for (i=1; i<=NR; i++) {
        $0 = lines[i];
        split($2, addr, "@");
        ip_port = addr[1];

        if ($3 ~ /master/) {
            # $9 adalah range slot (misal 0-5460)
            printf "MASTER  | %-19s | Slots: %s\n", ip_port, $9;
        }
    }

    print "------------------------------------------------"
    
    # Cetak Daftar Slave dan Pasangannya
    for (i=1; i<=NR; i++) {
        $0 = lines[i];
        split($2, addr, "@");
        ip_port = addr[1];

        if ($3 ~ /slave/) {
            master_id = $4;
            master_ip = id_map[master_id];
            
            # Jika master_ip kosong (mungkin belum sync), tulis ID-nya saja
            if (master_ip == "") master_ip = "ID: " master_id;

            printf "SLAVE   | %-19s | Replicates: %s\n", ip_port, master_ip;
        }
    }
    print "------------------------------------------------"
}'