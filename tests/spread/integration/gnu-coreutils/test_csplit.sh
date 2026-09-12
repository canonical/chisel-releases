#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucsplit

rootfs="$(install-slices gnu-coreutils_csplit)"
chroot "$rootfs" gnucsplit --version
printf "1\n2\n3\n4\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnucsplit test_file 3)" = $'4\n4'
test "$(cat "$rootfs/xx00")" = $'1\n2'
test "$(cat "$rootfs/xx01")" = $'3\n4'
