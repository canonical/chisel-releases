#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnumv

rootfs="$(install-slices gnu-coreutils_mv-bin)"
chroot "$rootfs" gnumv --version
touch "$rootfs/test_file"
chroot "$rootfs" gnumv test_file test_file_moved
test ! -e "$rootfs/test_file"
test -e "$rootfs/test_file_moved"
