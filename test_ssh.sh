#!/bin/bash
echo "=== TCP test ==="
timeout 5 bash -c 'exec 3<>/dev/tcp/192.168.4.196/8022; echo "connected"; read -t 3 -u 3 line; echo "RCV: $line"' 2>&1 || echo "TCP connect failed"

echo ""
echo "=== SSH with password ==="
timeout 10 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 8022 u0_a275@192.168.4.196 "echo SUCCESS" 2>&1 || echo "SSH failed"

echo ""
echo "=== nc raw ==="
echo "test" | timeout 5 nc -w 3 192.168.4.196 8022 2>&1 | head -5
echo "---done---"
