#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutest

rootfs="$(install-slices gnu-coreutils_test)"
chroot "$rootfs" "gnu[" --version
touch "$rootfs/test_file"
chroot "$rootfs" "gnu[" -e test_file "]"
chroot "$rootfs" gnutest -e test_file
rc=0
chroot "$rootfs" gnutest -e missing_file || rc=$?
test "$rc" = "1"
