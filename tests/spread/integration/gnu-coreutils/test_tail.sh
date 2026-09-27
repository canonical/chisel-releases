#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutail

rootfs="$(install-slices gnu-coreutils_tail)"
chroot "$rootfs" gnutail --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnutail -n 1 test_file)" = "line3"
test "$(chroot "$rootfs" gnutail -n +2 test_file)" = $'line2\nline3'
