#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_df-bin)"
chroot "$rootfs" df --version
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT
chroot "$rootfs" df /proc | grep -q " /proc$"
chroot "$rootfs" df -h / | grep -q "^Filesystem"
