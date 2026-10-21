#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_mkfifo)"
chroot "$rootfs" mkfifo --version
chroot "$rootfs" mkfifo test_fifo
test -p "$rootfs/test_fifo"
chroot "$rootfs" mkfifo -m 600 test_fifo2
test "$(stat -c '%a' "$rootfs/test_fifo2")" = "600"
