import time
import redis
import sys
from datetime import datetime

MASTER_HOST = "192.168.122.10"
REPLICA_HOSTS = ["192.168.122.20", "192.168.122.30"]
SENTINEL_HOSTS = ["192.168.122.40", "192.168.122.50", "192.168.122.60"]
MASTER_NAME = "mymaster"
PORT = 6379
SENTINEL_PORT = 26379
TEST_DURATION = 20

LOG_FILE = "sentinel_failover.log"

def log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    log_entry = f"[{timestamp}] {message}"
    print(log_entry)
    with open(LOG_FILE, "a") as f:
        f.write(log_entry + "\n")

def get_current_master():
    for sentinel_host in SENTINEL_HOSTS:
        try:
            sentinel = redis.Redis(host=sentinel_host, port=SENTINEL_PORT, socket_connect_timeout=2)
            master_info = sentinel.sentinel_get_master_addr_by_name(MASTER_NAME)
            if master_info:
                return master_info[0]
        except Exception as e:
            continue
    return None

def can_write_to_master(master_host):
    try:
        conn = redis.Redis(host=master_host, port=PORT, socket_connect_timeout=1)
        conn.set("failover_test", "ok")
        return True
    except Exception:
        return False

def crash_master(master_host):
    try:
        conn = redis.Redis(host=master_host, port=PORT, socket_connect_timeout=2)
        conn.execute_command("DEBUG", "SEGFAULT")
    except Exception:
        pass

def check_master_alive(master_host):
    try:
        conn = redis.Redis(host=master_host, port=PORT, socket_connect_timeout=1)
        conn.ping()
        return True
    except Exception:
        return False

def get_master_role(master_host):
    try:
        conn = redis.Redis(host=master_host, port=PORT, socket_connect_timeout=1)
        info = conn.info("replication")
        return info.get("role", "unknown")
    except Exception:
        return "unreachable"



def run_failover_test():
    log("")
    
    initial_master = get_current_master()
    if not initial_master:
        log("ERROR: Cannot detect current master from sentinel")
        return
    
    log(f"Current master: {initial_master}")
    
    # Write 1 key to confirm master is working
    log("Writing initial test key...")
    if can_write_to_master(initial_master):
        log("Initial write successful")
    else:
        log("WARNING: Initial write failed")
    
    # Crash master
    log(f"Crashing master {initial_master}...")
    crash_master(initial_master)
    time.sleep(0.5)
    
    # Try to write every 0.5s until failover completes
    log("Monitoring failover and attempting writes every 0.5s...")
    log("")
    log(f"{'Time (s)':<10} | {'Write Status':<15} | {'Current Master':<20}")
    
    start_time = time.time()
    failover_complete = False
    new_master = None
    downtime_start = None
    downtime_end = None
    write_success_count = 0
    write_fail_count = 0
    
    while time.time() - start_time < TEST_DURATION:
        elapsed = time.time() - start_time
        current_master = get_current_master()
        
        if current_master:
            write_ok = can_write_to_master(current_master)
            
            if write_ok:
                write_success_count += 1
                status = "OK"
                if downtime_start and not downtime_end:
                    downtime_end = time.time()
            else:
                write_fail_count += 1
                status = "FAILED"
                if not downtime_start:
                    downtime_start = time.time()
            
            log(f"{elapsed:<10.2f} | {status:<15} | {current_master:<20}")
            
            # Check if failover completed
            if current_master != initial_master and write_ok and not failover_complete:
                new_master = current_master
                failover_complete = True
                log("")
                log(f"Failover completed after {elapsed:.2f}s")
                log(f"Old master: {initial_master}")
                log(f"New master: {new_master}")
                if downtime_start and downtime_end:
                    downtime = downtime_end - downtime_start
                    log(f"Total downtime: {downtime:.2f}s")
                log(f"Write failures: {write_fail_count}")
                log(f"Write successes: {write_success_count}")
                
        else:
            write_fail_count += 1
            log(f"{elapsed:<10.2f} | {'FAILED':<15} | {'NO MASTER':<20}")
            if not downtime_start:
                downtime_start = time.time()
        
        # Check if old master recovered
        if failover_complete:
            old_master_status = get_master_role(initial_master)
            if old_master_status == "slave":
                log("")
                log(f"Old master {initial_master} recovered as replica")
                try:
                    conn = redis.Redis(host=initial_master, port=PORT, socket_connect_timeout=1)
                    info = conn.info("replication")
                    replicating_to = info.get("master_host", "unknown")
                    log(f"Now replicating from: {replicating_to}")
                except Exception:
                    pass
                break
        
        time.sleep(0.5)
    
    if not failover_complete:
        log("")
        log(f"WARNING: Failover did not complete within {TEST_DURATION}s")
    
    log("")

def main():
    with open(LOG_FILE, "w") as f:
        f.write("")
    
    log("Redis Sentinel Failover Test")
    log(f"Master: {MASTER_HOST}")
    log(f"Replicas: {', '.join(REPLICA_HOSTS)}")
    log(f"Sentinels: {', '.join(SENTINEL_HOSTS)}")
    log(f"Test duration: {TEST_DURATION}s")
    
    try:
        run_failover_test()
        
        log("Test completed")
        log(f"Log saved to: {LOG_FILE}")
        
    except KeyboardInterrupt:
        log("Test interrupted by user")
    except Exception as e:
        log(f"ERROR: {e}")
        import traceback
        log(traceback.format_exc())

if __name__ == "__main__":
    main()
