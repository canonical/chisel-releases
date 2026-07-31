#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices util-linux_cpu)"

mkdir "$rootfs"/sys
mkdir "$rootfs"/proc
mount --bind /sys "$rootfs"/sys
mount --bind /proc "$rootfs"/proc
trap "umount $rootfs/sys || true; umount $rootfs/proc || true" EXIT

chroot "$rootfs" lscpu | grep -q "Architecture"
