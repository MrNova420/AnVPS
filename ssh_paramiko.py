#!/usr/bin/env python3
import paramiko
import sys
import socket

host = '192.168.4.196'
port = 8022
user = 'u0_a275'
password = 's5600'

print(f"Connecting to {host}:{port} via paramiko...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(host, port=port, username=user, password=password, timeout=10, banner_timeout=10)
    print("CONNECTED!")
    stdin, stdout, stderr = client.exec_command("echo PARAMIKO_OK; whoami; hostname")
    print(stdout.read().decode())
    client.close()
except paramiko.SSHException as e:
    print(f"SSHException: {e}")
except socket.timeout:
    print("Socket timeout")
except Exception as e:
    print(f"Error: {type(e).__name__}: {e}")
