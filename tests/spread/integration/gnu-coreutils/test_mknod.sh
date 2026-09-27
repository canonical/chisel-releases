#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnumknod

rootfs="$(install-slices gnu-coreutils_mknod)"
chroot "$rootfs" gnumknod --version
chroot "$rootfs" gnumknod test_fifo p
test -p "$rootfs/test_fifo"
