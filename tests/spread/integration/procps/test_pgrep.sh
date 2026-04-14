#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_pgrep)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" pgrep --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" pgrep --version 2>&1 | grep -Fq 'pgrep from procps-ng'
