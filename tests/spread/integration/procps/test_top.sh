#!/usr/bin/env bash
# spellchecker: ignore rootfs procps terminfo

rootfs="$(install-slices procps_top)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" top --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" top --version 2>&1 | grep -Fq 'top from procps-ng'
chroot "$rootfs" top -bn1 2>&1 | grep -Fq 'PID'
