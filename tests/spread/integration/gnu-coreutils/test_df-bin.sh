#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudf

rootfs="$(install-slices gnu-coreutils_df-bin)"
chroot "$rootfs" gnudf --version
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT
chroot "$rootfs" gnudf /proc | grep -q " /proc$"
chroot "$rootfs" gnudf -h / | grep -q "^Filesystem"
