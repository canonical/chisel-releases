#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_ps-bin)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" ps --help 2>&1 | grep -iq 'usage:'
chroot "$rootfs" ps --version 2>&1 | grep -q 'ps from procps-ng'
chroot "$rootfs" ps aux 2>&1 | grep -q 'PID'