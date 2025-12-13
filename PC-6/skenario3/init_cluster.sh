echo "Moving Redis Config"
cp redis.conf /etc/redis/redis.conf

echo "Start Service"
service redis-server start
