#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_ls-bin)"
chroot "$rootfs" ls --version
mkdir -p "$rootfs/test_dir"
touch "$rootfs/test_dir/file1"
touch "$rootfs/test_dir/file2"
test "$(chroot "$rootfs" ls test_dir | sort)" = $'file1\nfile2'
test "$(chroot "$rootfs" ls -a test_dir | sort)" = $'.\n..\nfile1\nfile2'
