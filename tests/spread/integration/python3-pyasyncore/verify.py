"""A dispatcher on one end of a socket pair reads what the other end sends."""

import asyncore
import socket

a, b = socket.socketpair()
got = []


class Reader(asyncore.dispatcher):
    def handle_read(self):
        got.append(self.recv(64))
        self.close()


Reader(sock=a)
b.sendall(b"chisel")
asyncore.loop(timeout=1, count=5)
assert got == [b"chisel"], got
