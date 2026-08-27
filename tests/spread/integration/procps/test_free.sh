#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_free)"
mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT
chroot "$rootfs" free --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" free --version 2>&1 | grep -Fiq 'free from procps-ng'
chroot "$rootfs" free -m 2>&1 | grep -Fq 'Mem:'
