Script for killing the redis server
systemctl stop redis-server 2>/dev/null || true
pkill redis-server 2>/dev/null || true

SETUP FRESH PC-1
/root/bootstrap.sh
/root/setup_master.sh

SETUP FRESH PC-2
/root/bootstrap.sh
/root/setup_replica.sh 192.168.122.10

SETUP FRESH PC-3
/root/bootstrap.sh
/root/setup_replica.sh 192.168.122.10

SETUP FRESH PC-4
/root/run_experiment.sh
