#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices util-linux_logger)"

# Receive one datagram on a syslog-style unix socket inside the rootfs
python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
s.bind(sys.argv[1])
s.settimeout(30)
open(sys.argv[2], "wb").write(s.recv(4096))
' "$rootfs/log.sock" "$rootfs/received" &
receiver=$!
while [ ! -S "$rootfs/log.sock" ]; do sleep 0.1; done

chroot "$rootfs" logger --socket /log.sock -t chisel-test hello
wait "$receiver"
grep -q "chisel-test: hello" "$rootfs/received"
