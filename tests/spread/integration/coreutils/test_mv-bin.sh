#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_mv-bin)"
chroot "$rootfs" mv --version
touch "$rootfs/test_file"
chroot "$rootfs" mv test_file test_file_moved
test ! -e "$rootfs/test_file"
test -e "$rootfs/test_file_moved"
