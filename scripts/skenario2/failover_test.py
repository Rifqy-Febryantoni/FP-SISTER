import time
import redis
import threading
from datetime import datetime

# Configuration
MASTER_HOST = "192.168.122.10"
REPLICA_HOSTS = ["192.168.122.20", "192.168.122.30"]
SENTINEL_HOSTS = ["192.168.122.40", "192.168.122.50", "192.168.122.60"]
MASTER_NAME = "mymaster"
PORT = 6379
SENTINEL_PORT = 26379
TEST_DURATION = 60

LOG_FILE = "sentinel_failover.log"

# Shared state
write_stats = {"success": 0, "fail": 0}
stop_writing = False
log_lock = threading.Lock()

def log(message):
    timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    log_entry = f"[{timestamp}] {message}"
    with log_lock:
        print(log_entry)
        with open(LOG_FILE, "a") as f:
            f.write(log_entry + "\n")

def get_sentinel_conn(host):
    return redis.Redis(host=host, port=SENTINEL_PORT, socket_connect_timeout=1, socket_timeout=1, decode_responses=True)

def get_redis_conn(host):
    return redis.Redis(host=host, port=PORT, socket_connect_timeout=1, socket_timeout=1, decode_responses=True)

def get_master_from_sentinel():
    for host in SENTINEL_HOSTS:
        try:
            s = get_sentinel_conn(host)
            addr = s.sentinel_get_master_addr_by_name(MASTER_NAME)
            if addr:
                return addr[0]
        except:
            pass
    return None

def get_node_role(host):
    try:
        conn = get_redis_conn(host)
        info = conn.info("replication")
        return info.get("role", "unknown")
    except:
        return "unreachable"

def get_node_master(host):
    try:
        conn = get_redis_conn(host)
        info = conn.info("replication")
        if info.get("role") == "slave":
            return info.get("master_host", "unknown")
        return None
    except:
        return None

def crash_master(host):
    import socket
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.1)
        sock.connect((host, PORT))
        cmd = "*2\r\n$8\r\nSHUTDOWN\r\n$6\r\nNOSAVE\r\n"
        sock.send(cmd.encode())
        sock.close()
    except:
        pass

def write_loop():
    global write_stats, stop_writing
    key_counter = 0
    
    while not stop_writing:
        master = get_master_from_sentinel()
        if master:
            try:
                conn = get_redis_conn(master)
                conn.set(f"test_key_{key_counter}", f"value_{key_counter}")
                write_stats["success"] += 1
                key_counter += 1
            except:
                write_stats["fail"] += 1
        else:
            write_stats["fail"] += 1
        time.sleep(0.5)

def monitor_sentinels(initial_master, state):
    for host in SENTINEL_HOSTS:
        try:
            s = get_sentinel_conn(host)
            info = s.sentinel_master(MASTER_NAME)
            flags = info.get("flags", "")
            
            if "s_down" in flags:
                key = f"sdown_{host}"
                if not state.get(key):
                    log(f"[SENTINEL {host}] Master down detected (subjective)")
                    state[key] = True
            
            if "o_down" in flags:
                key = f"odown_{host}"
                if not state.get(key):
                    log(f"[SENTINEL {host}] Master confirmed down (objective) - quorum reached")
                    state[key] = True
            
            if "failover_in_progress" in flags:
                key = f"failover_{host}"
                if not state.get(key):
                    log(f"[SENTINEL {host}] Failover started")
                    state[key] = True
            
            leader = info.get("leader", "")
            leader_epoch = info.get("leader-epoch", "")
            if leader and leader != "?":
                key = f"leader_{leader}"
                if not state.get(key):
                    log(f"[ELECTION] Leader {leader} elected (epoch {leader_epoch})")
                    state[key] = True
            
        except:
            pass

def monitor_replicas(initial_master, new_master, state):
    if not new_master or new_master == initial_master:
        return
    
    for host in REPLICA_HOSTS:
        if host == new_master:
            continue
        
        master_of = get_node_master(host)
        if master_of == new_master:
            key = f"reconfigured_{host}"
            if not state.get(key):
                log(f"[REPLICA {host}] Reconfigured to replicate from new master {new_master}")
                state[key] = True

def monitor_old_master(initial_master, new_master, state):
    if not new_master or new_master == initial_master:
        return
    
    role = get_node_role(initial_master)
    
    if role == "slave":
        if not state.get("old_master_slave"):
            master_of = get_node_master(initial_master)
            log(f"[RECOVERY] Old master {initial_master} is back as REPLICA of {master_of}")
            state["old_master_slave"] = True
    elif role == "master":
        if not state.get("old_master_warning"):
            log(f"[WARNING] Old master {initial_master} detected back as MASTER")
            state["old_master_warning"] = True

def run_test():
    global stop_writing, write_stats
    
    stop_writing = False
    write_stats = {"success": 0, "fail": 0}
    
    initial_master = get_master_from_sentinel()
    if not initial_master:
        log("ERROR: Cannot get master from sentinel")
        return
    
    log(f"Initial master: {initial_master}")
    log(f"Replicas: {', '.join(REPLICA_HOSTS)}")
    log(f"Sentinels: {', '.join(SENTINEL_HOSTS)}")
    
    write_thread = threading.Thread(target=write_loop, daemon=True)
    write_thread.start()
    log("Started continuous write operations (every 0.5s)")
    
    time.sleep(2)
    log(f"Crashing master {initial_master}...")
    crash_time = time.time()
    crash_master(initial_master)
    log("Master crash command sent")
    
    state = {}
    new_master = None
    failover_time = None
    
    start_time = time.time()
    last_status_time = 0
    
    while time.time() - start_time < TEST_DURATION:
        elapsed = time.time() - crash_time
        
        monitor_sentinels(initial_master, state)
        
        current_master = get_master_from_sentinel()
        if current_master and current_master != initial_master:
            if not new_master:
                new_master = current_master
                failover_time = time.time() - crash_time
                log(f"[FAILOVER COMPLETE] New master: {new_master}")
                log(f"[FAILOVER COMPLETE] Time: {failover_time:.2f}s")
        
        if new_master:
            monitor_replicas(initial_master, new_master, state)
            monitor_old_master(initial_master, new_master, state)
        
        if time.time() - last_status_time >= 5:
            log(f"[STATUS] Writes: {write_stats['success']} OK, {write_stats['fail']} FAIL | Master: {current_master or 'NONE'}")
            last_status_time = time.time()
        
        if new_master and state.get("old_master_slave"):
            all_replicas_done = all(
                state.get(f"reconfigured_{h}") 
                for h in REPLICA_HOSTS 
                if h != new_master
            )
            if all_replicas_done and not state.get("all_done"):
                log("[COMPLETE] All nodes reconfigured successfully")
                state["all_done"] = True
        
        time.sleep(0.5)
    
    stop_writing = True
    time.sleep(0.5)
    
    log("=" * 50)
    log("FINAL SUMMARY")
    log("=" * 50)
    log(f"Initial master: {initial_master}")
    log(f"New master: {new_master or 'NO FAILOVER'}")
    if failover_time:
        log(f"Failover time: {failover_time:.2f}s")
    log(f"Total writes succeeded: {write_stats['success']}")
    log(f"Total writes failed: {write_stats['fail']}")
    if write_stats['success'] + write_stats['fail'] > 0:
        success_rate = write_stats['success'] / (write_stats['success'] + write_stats['fail']) * 100
        log(f"Write success rate: {success_rate:.1f}%")
    if (state.get('old_master_slave')):
        log("Old master recovered as replica")
    else:
        log("Old master did not recover as replica")
    log("=" * 50)

def main():
    with open(LOG_FILE, "w") as f:
        f.write("")
    
    log("=" * 50)
    log("REDIS SENTINEL FAILOVER TEST")
    log("=" * 50)
    
    try:
        run_test()
        log(f"Log saved to: {LOG_FILE}")
    except KeyboardInterrupt:
        log("Test interrupted")
    except Exception as e:
        log(f"ERROR: {e}")
        import traceback
        log(traceback.format_exc())

if __name__ == "__main__":
    main()
