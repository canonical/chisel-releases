#!/usr/bin/env bash

rootfs="$(install-slices gcc-15_lto)"

cp lto.c "$rootfs/lto.c"

chroot "$rootfs" gcc-15 -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto
test -x "$rootfs/lto"
