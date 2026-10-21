#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuln

rootfs="$(install-slices gnu-coreutils_ln-bin)"
chroot "$rootfs" gnuln --version
touch "$rootfs/test_file"
chroot "$rootfs" gnuln -s test_file test_link
test -L "$rootfs/test_link"
test "$(readlink "$rootfs/test_link")" = "test_file"
