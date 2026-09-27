#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_truncate)"
chroot "$rootfs" truncate --version
chroot "$rootfs" truncate -s 10 test_file
test "$(stat -c '%s' "$rootfs/test_file")" = "10"
chroot "$rootfs" truncate -s -4 test_file
test "$(stat -c '%s' "$rootfs/test_file")" = "6"
