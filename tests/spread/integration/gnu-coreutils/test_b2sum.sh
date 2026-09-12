#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnub2sum

rootfs="$(install-slices gnu-coreutils_b2sum)"
chroot "$rootfs" gnub2sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnub2sum test_file)" = \
    "e4cfa39a3d37be31c59609e807970799caa68a19bfaa15135f165085e01d41a65ba1e1b146aeb6bd0092b49eac214c103ccfa3a365954bbbe52f74a2b3620c94  test_file"
chroot "$rootfs" gnub2sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" gnub2sum -c test_file.sum | grep -q "test_file: OK"
