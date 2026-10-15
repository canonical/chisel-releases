#!/usr/bin/env bash

rootfs="$(install-slices gcc_lto)"

arch=$(uname -m)
arch="${arch//_/-}"
[ "$arch" = "ppc64le" ] && arch="powerpc64le"
arch_triplet="${arch}-linux-gnu"

cp "../gcc-15-${arch_triplet}/testfiles/lto.c" "$rootfs/lto.c"

chroot "$rootfs" gcc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto-gcc
test -x "$rootfs/lto-gcc"

chroot "$rootfs" cc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto-cc
test -x "$rootfs/lto-cc"
