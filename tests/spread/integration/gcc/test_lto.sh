#!/usr/bin/env bash

rootfs="$(install-slices gcc_lto)"

cp lto.c "$rootfs/lto.c"

chroot "$rootfs" gcc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto-gcc
test -x "$rootfs/lto-gcc"

chroot "$rootfs" cc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto-cc
test -x "$rootfs/lto-cc"
