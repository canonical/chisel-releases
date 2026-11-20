#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils

rootfs="$(install-slices bsdutils_wall)"

chroot "$rootfs" /usr/bin/wall --help | grep -q "Usage:"
chroot "$rootfs" /usr/bin/wall --version | grep -q "wall from"

# send a message without any other users logged in
# this should succeed but do nothing
echo "hello from wall" | chroot "$rootfs" /usr/bin/wall
