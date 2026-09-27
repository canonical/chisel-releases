#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_paste)"
chroot "$rootfs" paste --version
printf "a\nb\n" > "$rootfs/file1"
printf "1\n2\n" > "$rootfs/file2"
test "$(chroot "$rootfs" paste -d , file1 file2)" = $'a,1\nb,2'
