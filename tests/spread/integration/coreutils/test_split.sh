#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_split)"
chroot "$rootfs" split --version
printf "line1\nline2\n" > "$rootfs/test_file"
chroot "$rootfs" split -l 1 test_file
test "$(cat "$rootfs/xaa")" = "line1"
test "$(cat "$rootfs/xab")" = "line2"
