cat > /root/run_experiment.sh << 'EOF'
#!/bin/bash
set -e
/root/bootstrap.sh    # pastikan dependency ada
echo
python3 /root/replication_test.py
EOF

chmod +x /root/run_experiment.sh
