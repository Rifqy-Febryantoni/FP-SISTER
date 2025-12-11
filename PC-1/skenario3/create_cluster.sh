echo "Creating Cluster for nodes 10, 20, 30, 40, 50, 60"

echo "yes" | redis-cli --cluster create 192.168.122.10:6379 192.168.122.20:6379 192.168.122.30:6379 192.168.122.40:6379 192.168.122.50:6379 192.168.122.60:6379 --cluster-replicas 1

sleep 2

echo "CLUSTER STATUS"
redis-cli cluster nodes