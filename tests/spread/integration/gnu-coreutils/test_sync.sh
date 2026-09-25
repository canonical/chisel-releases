#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusync

rootfs="$(install-slices gnu-coreutils_sync)"
chroot "$rootfs" gnusync --version
touch "$rootfs/test_file"
chroot "$rootfs" gnusync
chroot "$rootfs" gnusync test_file
