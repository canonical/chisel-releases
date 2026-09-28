#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnureadlink

rootfs="$(install-slices gnu-coreutils_readlink)"
chroot "$rootfs" gnureadlink --version
touch "$rootfs/test_file"
ln -s test_file "$rootfs/test_link"
test "$(chroot "$rootfs" gnureadlink test_link)" = "test_file"
