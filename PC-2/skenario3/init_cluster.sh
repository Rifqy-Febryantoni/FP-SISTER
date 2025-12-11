echo "Moving Configuration from root"
cp /root/skenario3/redis.conf /etc/redis/redis.conf

echo "Start Service"
service redis-server start
