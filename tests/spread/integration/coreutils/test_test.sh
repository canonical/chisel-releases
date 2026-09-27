#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_test)"
chroot "$rootfs" "[" --version
touch "$rootfs/test_file"
chroot "$rootfs" "[" -e test_file "]"
chroot "$rootfs" test -e test_file
rc=0
chroot "$rootfs" test -e missing_file || rc=$?
test "$rc" = "1"
