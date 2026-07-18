#!/usr/bin/env python3
import socket, sys, os, subprocess, threading, signal

HOST = '0.0.0.0'
PORT = 9999

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((HOST, PORT))
s.listen(1)
print(f'Listening on {HOST}:{PORT}...', flush=True)

conn, addr = s.accept()
print(f'Connected: {addr}', flush=True)
conn.settimeout(None)

def reader():
    buf = b''
    while True:
        try:
            c = conn.recv(1)
            if not c:
                break
            buf += c
            if c == b'\n':
                line = buf.decode('utf-8', errors='replace').strip()
                if line:
                    print(f'[PHONE] {line}', flush=True)
                buf = b''
        except:
            break

t = threading.Thread(target=reader, daemon=True)
t.start()

while True:
    try:
        cmd = input('> ')
        if cmd.lower() in ('exit', 'quit'):
            conn.sendall(b'exit\n')
            break
        conn.sendall((cmd + '\n').encode())
    except (EOFError, KeyboardInterrupt):
        break

conn.close()
s.close()
