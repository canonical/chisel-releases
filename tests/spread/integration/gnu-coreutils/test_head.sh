#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuhead

rootfs="$(install-slices gnu-coreutils_head)"
chroot "$rootfs" gnuhead --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnuhead -n 1 test_file)" = "line1"
test "$(chroot "$rootfs" gnuhead -c 3 test_file)" = "lin"
