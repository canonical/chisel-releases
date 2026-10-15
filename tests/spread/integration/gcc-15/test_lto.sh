#!/usr/bin/env bash

rootfs="$(install-slices gcc-15_lto)"

arch=$(uname -m)
arch="${arch//_/-}"
[ "$arch" = "ppc64le" ] && arch="powerpc64le"
arch_triplet="${arch}-linux-gnu"

cp "../gcc-15-${arch_triplet}/testfiles/lto.c" "$rootfs/lto.c"

chroot "$rootfs" gcc-15 -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto
test -x "$rootfs/lto"
