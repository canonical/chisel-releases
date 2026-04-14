#!/usr/bin/env bash
# spellchecker: ignore rootfs procps terminfo

rootfs="$(install-slices procps_top)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" top --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" top --version 2>&1 | grep -Fq 'top from procps-ng'

# Run top in batch mode with bash and terminfo available
rootfs_2="$(install-slices procps_top bash_bins)"

mkdir -p "$rootfs_2"/proc
mount --bind /proc "$rootfs_2"/proc
trap "umount '$rootfs_2'/proc; umount '$rootfs'/proc" EXIT

chroot "$rootfs_2" top -bn1 2>&1 | grep -Fq 'PID'
