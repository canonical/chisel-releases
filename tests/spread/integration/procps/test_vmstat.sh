#!/usr/bin/env bash
# spellchecker: ignore rootfs procps vmstat

rootfs="$(install-slices procps_vmstat)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" vmstat --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" vmstat --version 2>&1 | grep -Fq 'vmstat from procps-ng'
chroot "$rootfs" vmstat 2>&1 | grep -Fq 'procs'
