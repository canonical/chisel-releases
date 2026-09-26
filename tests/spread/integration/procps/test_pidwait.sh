#!/usr/bin/env bash
# spellchecker: ignore rootfs procps pidwait

rootfs="$(install-slices procps_pidwait)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" pidwait --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" pidwait --version 2>&1 | grep -Fq 'pidwait from procps-ng'
