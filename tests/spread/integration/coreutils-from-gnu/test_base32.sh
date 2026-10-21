#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_base32)"
chroot "$rootfs" base32 --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" base32 test_file)" = "NBSWY3DP"
echo "NBSWY3DP" > "$rootfs/encoded"
test "$(chroot "$rootfs" base32 -d encoded)" = "hello"
