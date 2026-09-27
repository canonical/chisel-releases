#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_rmdir)"
chroot "$rootfs" rmdir --version
mkdir -p "$rootfs/test_dir"
chroot "$rootfs" rmdir test_dir
test ! -e "$rootfs/test_dir"
