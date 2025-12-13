echo "Moving Redis Config"
cp redis.conf /etc/redis/redis.conf

echo "Starting Redis Server"
service redis-server restart