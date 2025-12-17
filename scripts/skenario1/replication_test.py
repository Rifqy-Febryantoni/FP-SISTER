import time
import redis
import sys
import threading

MASTER_HOST = "192.168.122.10"     # pc-1 (master)
REPLICA_HOSTS = [
    ("192.168.122.20", "PC-2"), 
    ("192.168.122.30", "PC-3"), 
]

PORT = 6379
N = 1000
MODE = "concurrent"  
# MODE = "sequential"

READ_DELAY = 0.01    

def connect_to_redis():
    try:
        master = redis.Redis(host=MASTER_HOST, port=PORT, socket_connect_timeout=5)
        master.ping()
        
        replicas = []
        for host, name in REPLICA_HOSTS:
            conn = redis.Redis(host=host, port=PORT, socket_connect_timeout=5)
            conn.ping()
            replicas.append({"conn": conn, "host": host, "name": name})
        
        return master, replicas
    except redis.ConnectionError as e:
        print(f"\nConnection failed: {e}\n")
        sys.exit(1)


def read_from_replica(replica, retry_on_failure=False):
    missing = 0
    wrong = 0
    failed_keys = []
    
    t_start = time.time()
    for i in range(N):
        expected = str(i)
        val = replica['conn'].get(f"key:{i}")
        if val is None:
            missing += 1
            if retry_on_failure:
                failed_keys.append(i)
        elif val.decode() != expected:
            wrong += 1
            if retry_on_failure:
                failed_keys.append(i)
    t_end = time.time()
    
    # Retry until all keys synced or timeout
    if retry_on_failure and failed_keys:
        retry_attempts = 0
        max_retry_time = 10  # Maximum time
        retry_start = time.time()
        
        print(f"[{replica['name']}] Retrying {len(failed_keys)} failed keys ({missing} missing, {wrong} wrong)...")
        
        while failed_keys and (time.time() - retry_start < max_retry_time):
            time.sleep(0.5)
            retry_attempts += 1
            new_failed = []
            retry_missing = 0
            retry_wrong = 0
            
            for i in failed_keys:
                expected = str(i)
                val = replica['conn'].get(f"key:{i}")
                if val is None:
                    new_failed.append(i)
                    retry_missing += 1
                elif val.decode() != expected:
                    new_failed.append(i)
                    retry_wrong += 1
            
            failed_keys = new_failed
            
            if not failed_keys:
                print(f"[{replica['name']}] All keys synced after {retry_attempts} retry attempt(s)")
                break
            else:
                print(f"[{replica['name']}] Retry #{retry_attempts}: {retry_missing} missing, {retry_wrong} wrong (total: {len(failed_keys)} remaining)")
        
        # Final count
        missing = 0
        wrong = 0
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
    
    return {
        "name": replica['name'],
        "host": replica['host'],
        "missing": missing,
        "wrong": wrong,
        "synced": synced,
        "sync_pct": sync_pct,
        "read_time": read_time
    }


def sequential_test(master, replicas):
    print(f"Writing {N} keys to master...")
    t0 = time.time()
    for i in range(N):
        master.set(f"key:{i}", str(i))
    t1 = time.time()
    write_time = t1 - t0
    print(f"Done writes in {write_time:.4f} seconds\n")

    if READ_DELAY > 0:
        time.sleep(READ_DELAY)

    replica_stats = []
    for replica in replicas:
        print(f"Reading keys from {replica['name']} immediately...")
        stat = read_from_replica(replica)
        replica_stats.append(stat)
        
        print(f"{stat['name']} read time: {stat['read_time']:.4f} seconds")
        print(f"{stat['name']} missing keys: {stat['missing']}")
        print(f"{stat['name']} wrong value keys: {stat['wrong']}\n")
    
    return write_time, replica_stats


def concurrent_test(master, replicas):
    print(f"Writing {N} keys to master concurrently with reads...\n")
    
    write_time = 0
    replica_stats = []
    
    def write_thread():
        nonlocal write_time
        t0 = time.time()
        for i in range(N):
            master.set(f"key:{i}", str(i))
        t1 = time.time()
        write_time = t1 - t0
    
    def read_thread(replica):
        stat = read_from_replica(replica, retry_on_failure=True)
        replica_stats.append(stat)
    
    # Start write thread
    writer = threading.Thread(target=write_thread)
    writer.start()
    
    if READ_DELAY > 0:
        time.sleep(READ_DELAY)
    
    # Start read threads
    readers = []
    for replica in replicas:
        reader = threading.Thread(target=read_thread, args=(replica,))
        reader.start()
        readers.append(reader)
    
    # Wait for all threads
    writer.join()
    for reader in readers:
        reader.join()
    
    print(f"Done writes in {write_time:.4f} seconds\n")
    
    for stat in replica_stats:
        print(f"{stat['name']} read time: {stat['read_time']:.4f} seconds")
        print(f"{stat['name']} missing keys: {stat['missing']}")
        print(f"{stat['name']} wrong value keys: {stat['wrong']}\n")
    
    return write_time, replica_stats


def print_summary(write_time, replica_stats):
    print("\n--- Summary ---")
    print(f"Master: Wrote {N} keys in {write_time:.4f} seconds")
    for stat in replica_stats:
        print(f"{stat['name']}: {stat['synced']}/{N} synced ({stat['sync_pct']:.1f}%), {stat['missing']} missing, {stat['wrong']} wrong")


def main():
    print("REDIS REPLICATION LAG TEST")
    print(f"Mode: {MODE}\n")
    
    master, replicas = connect_to_redis()
    
    print("Flushing master database...")
    master.flushall()
    time.sleep(0.5)

    if MODE == "sequential":
        write_time, replica_stats = sequential_test(master, replicas)
    elif MODE == "concurrent":
        write_time, replica_stats = concurrent_test(master, replicas)
    else:
        print(f"Unknown mode: {MODE}")
        sys.exit(1)
    
    print_summary(write_time, replica_stats)


if __name__ == "__main__":
    main()
