#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_mknod)"
chroot "$rootfs" mknod --version
chroot "$rootfs" mknod test_fifo p
test -p "$rootfs/test_fifo"
