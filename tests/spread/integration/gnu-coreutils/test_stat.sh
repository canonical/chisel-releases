#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnustat

rootfs="$(install-slices gnu-coreutils_stat)"
chroot "$rootfs" gnustat --version
touch "$rootfs/test_file"
chroot "$rootfs" gnustat test_file
test "$(chroot "$rootfs" gnustat -c '%s' test_file)" = "0"
