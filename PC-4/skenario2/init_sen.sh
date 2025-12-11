echo "Moving Configuration from root"
cp /root/skenario2/sentinel.conf /etc/redis/sentinel.conf

echo "Starting Redis Server"
redis-sentinel /etc/redis/sentinel.conf