#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_pmap)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" pmap --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" pmap --version 2>&1 | grep -Fq 'pmap from procps-ng'
chroot "$rootfs" pmap 1 2>&1 | grep -Fq '1:'
