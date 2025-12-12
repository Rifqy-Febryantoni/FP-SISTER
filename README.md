### 1. Menjalankan dengan GNS3

<div align="center">
  <img width="581" src="https://github.com/user-attachments/assets/1ff07067-9ec9-43c1-b29d-da1c2f248201" />
</div>

Langkah-langkah:
1. Buka GNS3, lalu import file `.gns3project`.
2. Nyalakan semua node:
   `pc-1, pc-2, pc-3, pc-4, pc-5, pc-6`
3. Buka Console pada semua node.
4. Masuk ke direktori root:
   
   ```
   cd /root
   ```
   
6. Install dependency (jalankan di semua node):
   
   ```
   echo "nameserver 8.8.8.8" > /etc/resolv.conf
   apt-get update
   apt-get install -y redis redis-sentinel procps net-tools
   ```
   
------------------------------------------------------------

### 2. Menjalankan dengan Docker (Local Machine)

<div align="center">
  <img width="1582" src="https://github.com/user-attachments/assets/e1555b59-3a51-4ac0-aa46-2eab548146dc" />
</div>

Langkah-langkah:
1. Pull/clone repository ini.
2. Build & run:
   
   ```
   docker-compose up -d --build
   ```
4. Buka 6 terminal dan masuk ke setiap container:
   
   ```
   docker exec -it pc-1 bash
   docker exec -it pc-2 bash
   docker exec -it pc-3 bash
   docker exec -it pc-4 bash
   docker exec -it pc-5 bash
   docker exec -it pc-6 bash
   ```
   
------------------------------------------------------------

### SKENARIO 1 — Replication Lag Test

Tujuan:
Mengukur replication lag dan konsistensi data antara Master–Replica.

1. Inisialisasi replikasi (jalankan di semua node):
   
   ```
   ./skenario1/init_rep.sh
   ```
   
3. Cek peran Master/Replica (jalankan di semua node):
   
   ```
   ./skenario1/replication.sh
   ```

Target Output:
pc-1: role: master
pc-2: role: slave
pc-3: role: slave
pc-4: role: slave
pc-5: role: slave
pc-6: role: slave

Pekerja:
1. Kirim 1000 operasi SET ke master.
2. Segera baca dari replica.
3. Catat jumlah key yang belum tersinkron.

------------------------------------------------------------

### SKENARIO 2 — High Availability (Sentinel)

Tujuan:
Menguji deteksi kegagalan master dan proses failover otomatis oleh Sentinel.

1. Aktifkan Sentinel (jalankan di PC-4, PC-5, PC-6):
   
   ```
   ./skenario2/init_sen.sh
   ```

3. Verifikasi status Sentinel (khusus di PC-4):
   
   ```
   ./skenario2/sentinel.sh
   ```
   
Target Output:
status=ok
slaves=2
sentinels=3

Pekerja:
1. Matikan master (kill container atau stop service).
2. Amati:
   - Waktu failover
   - Replica mana yang menjadi master baru
   - Pengaruh penulisan data selama failover

------------------------------------------------------------

### SKENARIO 3 — Cluster Sharding

Tujuan:
Menguji distribusi penyimpanan data ke node-node dalam Redis Cluster.

Jika sebelumnya telah menjalankan skenario 1 atau 2, jalankan: `./clean.sh`

1. Setup konfigurasi cluster (jika belum clean.sh), jalankan di semua node:
   
   ```
   ./skenario3/init_cluster.sh
   ```

3. Create cluster (khusus PC-1):
   
   ```
   ./skenario3/create_cluster.sh
   ```

Target Output:
[OK] All 16384 slots covered.

Pekerja:
- Simpan key dengan pola key0–key10000.
- Amati key mapping ke tiap node cluster.
