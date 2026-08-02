#!/bin/bash
#spellchecker: ignore rootfs fsfreeze findfs swaplabel wipefs dosfstools
#spellchecker: ignore mountpoint vfat fschk

rootfs="$(install-slices util-linux_file-system)"

mkdir "$rootfs"/sys
mkdir "$rootfs"/proc
mount --bind /sys "$rootfs"/sys
mount --bind /proc "$rootfs"/proc
trap "umount $rootfs/sys || true; umount $rootfs/proc || true" EXIT

chroot "$rootfs" findmnt | grep -q "/sys"
chroot "$rootfs" mountpoint /sys | grep -q "/sys is a mountpoint"
chroot "$rootfs" findfs --help

# Dry run, outputs differ across different system configurations
chroot "$rootfs" fsck -N | grep -q "fsck from util-linux"
chroot "$rootfs" fsfreeze --help | grep -iq "usage"
chroot "$rootfs" fstrim --help  | grep -iq "usage"

chroot "$rootfs" mkswap --help | grep -iq "usage"
chroot "$rootfs" swaplabel --help | grep -iq "usage"
chroot "$rootfs" wipefs --help | grep -iq "usage"

# Test mkfs with an image file and verify it with fsck
# Using the mkfs.vfat from the host, as `mkfs.*` is not shipped
# by util-linux package any more since Ubuntu 24.10.
rootfs="$(install-slices \
    util-linux_file-system \
    util-linux_file-manipulation \
    dosfstools_mkfs \
    dosfstools_fschk \
)"

mkdir -p "$rootfs"/tmp
chroot "$rootfs" fallocate --length 16M /tmp/mkfs-test

chroot "$rootfs" mkfs -t vfat /tmp/mkfs-test
chroot "$rootfs" fsck -n /tmp/mkfs-test
