#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_head)"
chroot "$rootfs" head --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" head -n 1 test_file)" = "line1"
test "$(chroot "$rootfs" head -c 3 test_file)" = "lin"
