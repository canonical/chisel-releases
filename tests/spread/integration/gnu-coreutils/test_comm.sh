#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucomm

rootfs="$(install-slices gnu-coreutils_comm)"
chroot "$rootfs" gnucomm --version
printf "a\nb\nc\n" > "$rootfs/file1"
printf "b\nc\nd\n" > "$rootfs/file2"
test "$(chroot "$rootfs" gnucomm -12 file1 file2)" = $'b\nc'
test "$(chroot "$rootfs" gnucomm -23 file1 file2)" = "a"
