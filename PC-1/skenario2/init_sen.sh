echo "Moving Configuration from root"
cp /root/skenario1/redis.conf /etc/redis/redis.conf

echo "Starting Redis Server"
service redis-server restart