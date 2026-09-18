#!/usr/bin/env python3
"""Stream the Hyprland cursor position as "x, y" lines, one per change.

X11 lets xeyes query the pointer outside its window. Wayland sends pointer
events only while the pointer is over a client's surface. Hyprland provides
the global position through `cursorpos` on its request socket. The returned
coordinates use the monitor layout's coordinate system.

Hyprland closes the connection after each reply, so this reconnects for every
poll. It talks to the socket directly instead of starting `hyprctl` for every
sample. Unchanged positions are not printed, which avoids duplicate widget
updates.

Usage: cursor-tracker.py <request-socket-path> [interval-seconds]
"""

import socket
import sys
import time
from math import isfinite

RETRY_DELAY = 1.0


def parse_interval(value):
    try:
        interval = float(value)
    except (TypeError, ValueError) as error:
        raise ValueError("interval must be a number greater than zero") from error
    if not isfinite(interval) or interval <= 0:
        raise ValueError("interval must be a number greater than zero")
    return interval


def poll(path):
    with socket.socket(socket.AF_UNIX) as sock:
        sock.connect(path)
        sock.sendall(b"cursorpos")
        return sock.recv(64).decode("utf-8", "replace").strip()


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: cursor-tracker.py <request-socket-path> [interval-seconds]")
    path = sys.argv[1]
    try:
        interval = parse_interval(sys.argv[2]) if len(sys.argv) > 2 else 1.0 / 60.0
    except ValueError as error:
        sys.exit(str(error))

    last = None
    while True:
        try:
            position = poll(path)
        except OSError:
            # The shell starts a new helper when Hyprland exposes a new socket.
            time.sleep(RETRY_DELAY)
            continue
        if position and position != last:
            last = position
            print(position, flush=True)
        time.sleep(interval)


if __name__ == "__main__":
    main()
