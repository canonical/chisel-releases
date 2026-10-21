#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_readlink)"
chroot "$rootfs" readlink --version
touch "$rootfs/test_file"
ln -s test_file "$rootfs/test_link"
test "$(chroot "$rootfs" readlink test_link)" = "test_file"
