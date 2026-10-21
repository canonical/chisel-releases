#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuinstall

rootfs="$(install-slices gnu-coreutils_install)"
chroot "$rootfs" gnuinstall --version
touch "$rootfs/test_file"
chroot "$rootfs" gnuinstall -D -m 0750 test_file /tmp/test_file
test -f "$rootfs/tmp/test_file"
test "$(stat -c '%a' "$rootfs/tmp/test_file")" = "750"
