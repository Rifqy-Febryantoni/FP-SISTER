echo "Moving Redis Config"
cp sentinel.conf /etc/redis/sentinel.conf

echo "Starting Redis Server"
redis-sentinel /etc/redis/sentinel.conf