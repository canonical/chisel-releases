#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnurm

rootfs="$(install-slices gnu-coreutils_rm-bin)"
chroot "$rootfs" gnurm --version
touch "$rootfs/test_file"
chroot "$rootfs" gnurm test_file
test ! -e "$rootfs/test_file"
mkdir -p "$rootfs/test_dir/sub_dir"
chroot "$rootfs" gnurm -r test_dir
test ! -e "$rootfs/test_dir"
