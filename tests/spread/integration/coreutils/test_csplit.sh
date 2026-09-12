#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_csplit)"
chroot "$rootfs" csplit --version
printf "1\n2\n3\n4\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" csplit test_file 3)" = $'4\n4'
test "$(cat "$rootfs/xx00")" = $'1\n2'
test "$(cat "$rootfs/xx01")" = $'3\n4'
