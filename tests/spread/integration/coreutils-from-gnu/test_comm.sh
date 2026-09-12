#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_comm)"
chroot "$rootfs" comm --version
printf "a\nb\nc\n" > "$rootfs/file1"
printf "b\nc\nd\n" > "$rootfs/file2"
test "$(chroot "$rootfs" comm -12 file1 file2)" = $'b\nc'
test "$(chroot "$rootfs" comm -23 file1 file2)" = "a"
