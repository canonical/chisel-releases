#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_sum)"
chroot "$rootfs" sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" sum test_file)" = "08403     1 test_file"
test "$(chroot "$rootfs" sum -s test_file)" = "532 1 test_file"
