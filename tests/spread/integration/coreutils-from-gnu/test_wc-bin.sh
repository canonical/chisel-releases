#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_wc-bin)"
chroot "$rootfs" wc --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" wc -l < "$rootfs/test_file")" = "3"
test "$(chroot "$rootfs" wc -w < "$rootfs/test_file")" = "3"
test "$(chroot "$rootfs" wc -c < "$rootfs/test_file")" = "18"
