import pty, os, sys, subprocess

cmd = ["bash", "-c", """
options=("Cancel" "Install" "Cleanup")
echo "HELLO BANNER"
CHOICE=$(gum filter --height 6 --no-limit --no-strict --indicator="> " "${options[@]}")
"""]

master, slave = pty.openpty()
p = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, close_fds=True, env={**os.environ, "TERM": "xterm-256color", "LINES": "30", "COLUMNS": "120"})
os.close(slave)

import select
out = b""
while True:
    r, _, _ = select.select([master], [], [], 0.5)
    if r:
        out += os.read(master, 1024)
    else:
        break

print(out.decode('utf-8', errors='replace'))
