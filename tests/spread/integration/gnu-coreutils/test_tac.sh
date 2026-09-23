#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutac

rootfs="$(install-slices gnu-coreutils_tac)"
chroot "$rootfs" gnutac --version
printf "line1\nline2\nline3\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnutac test_file)" = $'line3\nline2\nline1'
