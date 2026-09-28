#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_tail)"
chroot "$rootfs" tail --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" tail -n 1 test_file)" = "line3"
test "$(chroot "$rootfs" tail -n +2 test_file)" = $'line2\nline3'
