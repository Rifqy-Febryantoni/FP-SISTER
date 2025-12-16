import time
import redis
import sys

MASTER_HOST = "192.168.122.10"     # pc-1 (master)
REPLICA_HOSTS = [
    ("192.168.122.20", "Replica-1"),  # pc-2
    ("192.168.122.30", "Replica-2"),  # pc-3
]

PORT = 6379
N = 1000

print("REDIS REPLICATION LAG TEST")

try:
    master = redis.Redis(host=MASTER_HOST, port=PORT, socket_connect_timeout=5)
    master.ping()
    
    replicas = []
    for host, name in REPLICA_HOSTS:
        conn = redis.Redis(host=host, port=PORT, socket_connect_timeout=5)
        conn.ping()
        replicas.append({"conn": conn, "host": host, "name": name})
    
except redis.ConnectionError as e:
    print(f"\nConnection failed: {e}\n")
    sys.exit(1)

# Clean DB on master
print("Flushing master database...")
master.flushall()
time.sleep(0.5)

# write 1000 keys
print(f"Writing {N} keys to master...")
t0 = time.time()
for i in range(N):
    master.set(f"key:{i}", str(i))
t1 = time.time()
write_time = t1 - t0
print(f"Done writes in {write_time:.4f} seconds\n")

# read from replicas
replica_stats = []

for replica in replicas:
    print(f"Reading keys from {replica['name']} immediately...")
    missing = 0
    wrong = 0
    
    t_start = time.time()
    for i in range(N):
        expected = str(i)
        val = replica['conn'].get(f"key:{i}")
        if val is None:
            missing += 1
        elif val.decode() != expected:
            wrong += 1
    t_end = time.time()
    
    read_time = t_end - t_start
    synced = N - missing - wrong
    sync_pct = (synced / N) * 100
    
    replica_stats.append({
        "name": replica['name'],
        "host": replica['host'],
        "missing": missing,
        "wrong": wrong,
        "synced": synced,
        "sync_pct": sync_pct,
        "read_time": read_time
    })
    
    print(f"{replica['name']} read time: {read_time:.4f} seconds")
    print(f"{replica['name']} missing keys: {missing}")
    print(f"{replica['name']} wrong value keys: {wrong}\n")

# Measure time until all replicas are consistent
total_unsynced = sum(stat['missing'] + stat['wrong'] for stat in replica_stats)

if total_unsynced > 0:
    print("Measuring lag until both replicas are fully consistent...")

    start_wait = time.time()
    checks = 0
    while True:
        all_synced = True
        
        for i in range(N):
            expected = str(i)
            
            # Check all replicas
            for replica in replicas:
                val = replica['conn'].get(f"key:{i}")
                if val is None or val.decode() != expected:
                    all_synced = False
                    break
            
            if not all_synced:
                break
        
        checks += 1
        if all_synced:
            break
        
        time.sleep(0.05)

    end_wait = time.time()
    lag_total = end_wait - start_wait
    print(f"Both replicas became fully consistent after {lag_total:.4f} seconds.")
else:
    print("Both replicas were already fully consistent.")
    lag_total = 0.0

# Summary
print("\n--- Summary ---")
print(f"Master: Wrote {N} keys in {write_time:.4f} seconds")
for stat in replica_stats:
    print(f"{stat['name']}: {stat['synced']}/{N} synced ({stat['sync_pct']:.1f}%), {stat['missing']} missing, {stat['wrong']} wrong")
print(f"Replication lag: {lag_total:.4f} seconds")
