#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_base64)"
chroot "$rootfs" base64 --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" base64 test_file)" = "aGVsbG8="
echo "aGVsbG8=" > "$rootfs/encoded"
test "$(chroot "$rootfs" base64 -d encoded)" = "hello"
