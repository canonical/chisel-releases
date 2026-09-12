#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuwc

rootfs="$(install-slices gnu-coreutils_wc-bin)"
chroot "$rootfs" gnuwc --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnuwc -l < "$rootfs/test_file")" = "3"
test "$(chroot "$rootfs" gnuwc -w < "$rootfs/test_file")" = "3"
test "$(chroot "$rootfs" gnuwc -c < "$rootfs/test_file")" = "18"
