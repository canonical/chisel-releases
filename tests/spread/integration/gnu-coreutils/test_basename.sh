#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnubasename

rootfs="$(install-slices gnu-coreutils_basename)"
chroot "$rootfs" gnubasename --version
test "$(chroot "$rootfs" gnubasename /foo/bar/test_file)" = "test_file"
test "$(chroot "$rootfs" gnubasename /foo/bar/test_file.txt .txt)" = "test_file"
