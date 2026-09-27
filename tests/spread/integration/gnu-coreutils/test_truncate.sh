#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutruncate

rootfs="$(install-slices gnu-coreutils_truncate)"
chroot "$rootfs" gnutruncate --version
chroot "$rootfs" gnutruncate -s 10 test_file
test "$(stat -c '%s' "$rootfs/test_file")" = "10"
chroot "$rootfs" gnutruncate -s -4 test_file
test "$(stat -c '%s' "$rootfs/test_file")" = "6"
