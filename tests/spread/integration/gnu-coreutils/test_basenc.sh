#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnubasenc

rootfs="$(install-slices gnu-coreutils_basenc)"
chroot "$rootfs" gnubasenc --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnubasenc --base16 test_file)" = "68656C6C6F"
# NOTE: base58 is the encoding that goes through libgmp
test "$(chroot "$rootfs" gnubasenc --base58 test_file)" = "Cn8eVZg"
echo "68656C6C6F" > "$rootfs/encoded"
test "$(chroot "$rootfs" gnubasenc --base16 -d encoded)" = "hello"
