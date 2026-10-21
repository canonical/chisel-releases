#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnupaste

rootfs="$(install-slices gnu-coreutils_paste)"
chroot "$rootfs" gnupaste --version
printf "a\nb\n" > "$rootfs/file1"
printf "1\n2\n" > "$rootfs/file2"
test "$(chroot "$rootfs" gnupaste -d , file1 file2)" = $'a,1\nb,2'
