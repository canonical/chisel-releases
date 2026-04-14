#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_w-bin)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" w --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" w --version 2>&1 | grep -Fq 'w from procps-ng'

# check that w outputs uptime info and column headers
chroot "$rootfs" w 2>&1 | head -1 | grep -Fq 'up'
chroot "$rootfs" w 2>&1 | grep -Fq 'USER'