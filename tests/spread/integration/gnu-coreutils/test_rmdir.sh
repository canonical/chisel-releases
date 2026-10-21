#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnurmdir

rootfs="$(install-slices gnu-coreutils_rmdir)"
chroot "$rootfs" gnurmdir --version
mkdir -p "$rootfs/test_dir"
chroot "$rootfs" gnurmdir test_dir
test ! -e "$rootfs/test_dir"
