#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnulink gnuunlink

rootfs="$(install-slices gnu-coreutils_link gnu-coreutils_unlink)"
chroot "$rootfs" gnuunlink --version
touch "$rootfs/test_file"
chroot "$rootfs" gnulink test_file test_file_link
test -e "$rootfs/test_file_link"
chroot "$rootfs" gnuunlink test_file_link
test ! -e "$rootfs/test_file_link"
