#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_basenc)"
chroot "$rootfs" basenc --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" basenc --base16 test_file)" = "68656C6C6F"
# NOTE: base58 is the encoding that goes through libgmp
test "$(chroot "$rootfs" basenc --base58 test_file)" = "Cn8eVZg"
echo "68656C6C6F" > "$rootfs/encoded"
test "$(chroot "$rootfs" basenc --base16 -d encoded)" = "hello"
