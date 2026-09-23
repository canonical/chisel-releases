#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_ln-bin)"
chroot "$rootfs" ln --version
touch "$rootfs/test_file"
chroot "$rootfs" ln -s test_file test_link
test -L "$rootfs/test_link"
test "$(readlink "$rootfs/test_link")" = "test_file"
