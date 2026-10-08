#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusplit

rootfs="$(install-slices gnu-coreutils_split)"
chroot "$rootfs" gnusplit --version
printf "line1\nline2\n" > "$rootfs/test_file"
chroot "$rootfs" gnusplit -l 1 test_file
test "$(cat "$rootfs/xaa")" = "line1"
test "$(cat "$rootfs/xab")" = "line2"
