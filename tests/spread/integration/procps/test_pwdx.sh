#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_pwdx)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" pwdx --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" pwdx --version 2>&1 | grep -Fq 'pwdx from procps-ng'
chroot "$rootfs" pwdx 1 2>&1 | grep -Fq '1:'
