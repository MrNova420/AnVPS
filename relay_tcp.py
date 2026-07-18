#!/usr/bin/env python3
import socket, subprocess, os, select, sys

HOST = '0.0.0.0'
PORT = 11111

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((HOST, PORT))
s.listen(1)
print(f'Listening on {HOST}:{PORT}...', flush=True)

conn, addr = s.accept()
print(f'Connected: {addr}', flush=True)
conn.settimeout(None)

while True:
    try:
        user_input = input('> ')
    except (EOFError, KeyboardInterrupt):
        break
    if user_input.lower() in ('exit', 'quit'):
        conn.sendall(b'exit\n')
        break
    conn.sendall((user_input + '\n').encode())
    conn.settimeout(30)
    try:
        data = conn.recv(65536)
        if data:
            print(data.decode('utf-8', errors='replace'), end='')
        else:
            print('[connection closed]')
            break
    except socket.timeout:
        print('[timeout]')
    except Exception as e:
        print(f'[error: {e}]')
        break

conn.close()
s.close()
