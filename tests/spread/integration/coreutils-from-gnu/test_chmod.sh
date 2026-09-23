#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_chmod)"
chroot "$rootfs" chmod --version
touch "$rootfs/test_file"
chroot "$rootfs" chmod 700 test_file
test "$(stat -c '%a' "$rootfs/test_file")" = "700"
chroot "$rootfs" chmod u-x,g+r test_file
test "$(stat -c '%a' "$rootfs/test_file")" = "640"
