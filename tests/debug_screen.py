#!/usr/bin/env python3
"""Debug what's on screen when the menu renders."""
import os, sys, time, pty, select, termios, pathlib, pyte, struct, fcntl, subprocess

REPO_ROOT = pathlib.Path(__file__).parent.parent
SCRIPT = str(REPO_ROOT / "antigravity-manager.sh")
COLS, ROWS = 120, 30

screen = pyte.Screen(COLS, ROWS)
stream = pyte.ByteStream(screen)

master_fd, slave_fd = pty.openpty()
winsize = struct.pack("HHHH", ROWS, COLS, 0, 0)
fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, winsize)

proc = subprocess.Popen(
    ["bash", SCRIPT, "--demo-ui"],
    stdin=slave_fd, stdout=slave_fd, stderr=slave_fd, close_fds=True,
    env={**os.environ, "TERM": "xterm-256color", "COLUMNS": str(COLS), "LINES": str(ROWS)},
)
os.close(slave_fd)

deadline = time.time() + 20
while time.time() < deadline:
    r, _, _ = select.select([master_fd], [], [], 0.1)
    if r:
        data = os.read(master_fd, 4096)
        stream.feed(data)
    if "navigate" in "\n".join("".join(screen.buffer[r][c].data for c in range(COLS)) for r in range(ROWS)):
        time.sleep(0.3)
        break

print("=" * 60)
print(f"FULL SCREEN STATE (120x30):")
print("=" * 60)
for row in range(ROWS):
    line = "".join(screen.buffer[row][c].data for c in range(COLS)).rstrip()
    print(f"ROW {row:02d}: |{line}|")

proc.terminate()
