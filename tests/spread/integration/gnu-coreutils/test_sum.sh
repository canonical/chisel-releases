#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusum

rootfs="$(install-slices gnu-coreutils_sum)"
chroot "$rootfs" gnusum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnusum test_file)" = "08403     1 test_file"
test "$(chroot "$rootfs" gnusum -s test_file)" = "532 1 test_file"
