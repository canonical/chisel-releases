#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnubase64

rootfs="$(install-slices gnu-coreutils_base64)"
chroot "$rootfs" gnubase64 --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnubase64 test_file)" = "aGVsbG8="
echo "aGVsbG8=" > "$rootfs/encoded"
test "$(chroot "$rootfs" gnubase64 -d encoded)" = "hello"
