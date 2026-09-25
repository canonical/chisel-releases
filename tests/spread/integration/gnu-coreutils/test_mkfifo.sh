#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnumkfifo

rootfs="$(install-slices gnu-coreutils_mkfifo)"
chroot "$rootfs" gnumkfifo --version
chroot "$rootfs" gnumkfifo test_fifo
test -p "$rootfs/test_fifo"
chroot "$rootfs" gnumkfifo -m 600 test_fifo2
test "$(stat -c '%a' "$rootfs/test_fifo2")" = "600"
