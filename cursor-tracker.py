#!/usr/bin/env python3
"""Stream the Hyprland cursor position as "x, y" lines, one per change.

Under X11 any client could ask the server where the pointer was, which is how
xeyes followed a cursor that was nowhere near its own window. Wayland gives a
client pointer events only while the pointer is over its own surface, so the
eyes have to ask the compositor instead: Hyprland answers `cursorpos` on its
request socket, in the same layout coordinates the monitors are placed in.

Hyprland closes the connection after each reply, so this reconnects per poll —
about 30us of work per sample, versus ~4ms to spawn `hyprctl` for the same
answer. Unchanged positions are not printed, so an idle cursor costs the
widget nothing.

Usage: cursor-tracker.py <request-socket-path> [interval-seconds]
"""

import socket
import sys
import time

RETRY_DELAY = 1.0


def poll(path):
    with socket.socket(socket.AF_UNIX) as sock:
        sock.connect(path)
        sock.sendall(b"cursorpos")
        return sock.recv(64).decode("utf-8", "replace").strip()


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: cursor-tracker.py <request-socket-path> [interval-seconds]")
    path = sys.argv[1]
    interval = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0 / 60.0

    last = None
    while True:
        try:
            position = poll(path)
        except OSError:
            # Hyprland is gone or restarting; the socket path changes with the
            # instance, so the shell will respawn us with the new one.
            time.sleep(RETRY_DELAY)
            continue
        if position and position != last:
            last = position
            print(position, flush=True)
        time.sleep(interval)


if __name__ == "__main__":
    main()
