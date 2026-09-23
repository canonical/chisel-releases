#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchmod

rootfs="$(install-slices gnu-coreutils_chmod)"
chroot "$rootfs" gnuchmod --version
touch "$rootfs/test_file"
chroot "$rootfs" gnuchmod 700 test_file
test "$(stat -c '%a' "$rootfs/test_file")" = "700"
chroot "$rootfs" gnuchmod u-x,g+r test_file
test "$(stat -c '%a' "$rootfs/test_file")" = "640"
