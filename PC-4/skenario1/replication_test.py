import time
import redis

MASTER_HOST = "192.168.122.10"     # pc-1 (master)
REPLICA1_HOST = "192.168.122.20"   # pc-2 (replica-1)
REPLICA2_HOST = "192.168.122.30"   # pc-3 (replica-2)

PORT = 6379
N = 1000

master = redis.Redis(host=MASTER_HOST, port=PORT)
replica1 = redis.Redis(host=REPLICA1_HOST, port=PORT)
replica2 = redis.Redis(host=REPLICA2_HOST, port=PORT)

# Clean DB on master
print("Flushing master database...")
master.flushall()
time.sleep(0.2)

# write 1000 keys
print(f"Writing {N} keys to master...")
t0 = time.time()
for i in range(N):
    master.set(f"key:{i}", str(i))
t1 = time.time()
print(f"Done writes in {t1 - t0:.4f} seconds\n")

# read from replica 1
print("Reading keys from Replica-1 immediately...")
missing1 = 0
wrong1 = 0

t2 = time.time()
for i in range(N):
    expected = str(i)
    val = replica1.get(f"key:{i}")
    if val is None:
        missing1 += 1
    elif val.decode() != expected:
        wrong1 += 1
t3 = time.time()

print(f"Replica-1 read time: {t3 - t2:.4f} seconds")
print(f"Replica-1 missing keys: {missing1}")
print(f"Replica-1 wrong value keys: {wrong1}\n")

# read from replica 2
print("Reading keys from Replica-2 immediately...")
missing2 = 0
wrong2 = 0

t4 = time.time()
for i in range(N):
    expected = str(i)
    val = replica2.get(f"key:{i}")
    if val is None:
        missing2 += 1
    elif val.decode() != expected:
        wrong2 += 1
t5 = time.time()

print(f"Replica-2 read time: {t5 - t4:.4f} seconds")
print(f"Replica-2 missing keys: {missing2}")
print(f"Replica-2 wrong value keys: {wrong2}\n")

# measure time until all replicas are consistent (sync)
if missing1 + wrong1 + missing2 + wrong2 > 0:
    print("Measuring lag until both replicas are fully consistent...")

    start_wait = time.time()
    while True:
        m1 = w1 = m2 = w2 = 0

        for i in range(N):
            expected = str(i)

            # replica 1
            val1 = replica1.get(f"key:{i}")
            if val1 is None:
                m1 += 1
            elif val1.decode() != expected:
                w1 += 1

            # replica 2
            val2 = replica2.get(f"key:{i}")
            if val2 is None:
                m2 += 1
            elif val2.decode() != expected:
                w2 += 1

        if m1 + w1 + m2 + w2 == 0:
            break

        time.sleep(0.05)

    end_wait = time.time()
    lag_total = end_wait - start_wait
    print(f"Both replicas became fully consistent after {lag_total:.4f} seconds.")
else:
    print("Both replicas were already fully consistent (no lag).")
