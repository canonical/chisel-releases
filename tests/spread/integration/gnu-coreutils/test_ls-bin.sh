#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuls

rootfs="$(install-slices gnu-coreutils_ls-bin)"
chroot "$rootfs" gnuls --version
mkdir -p "$rootfs/test_dir"
touch "$rootfs/test_dir/file1"
touch "$rootfs/test_dir/file2"
test "$(chroot "$rootfs" gnuls test_dir | sort)" = $'file1\nfile2'
test "$(chroot "$rootfs" gnuls -a test_dir | sort)" = $'.\n..\nfile1\nfile2'
