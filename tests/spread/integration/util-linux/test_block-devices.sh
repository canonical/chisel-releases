#!/bin/bash
#spellchecker: ignore rootfs partx blkdiscard blockdev zramctl

rootfs="$(install-slices util-linux_block-devices)"

mkdir "$rootfs"/sys
mount --bind /sys "$rootfs"/sys
trap "umount $rootfs/sys || true" EXIT

chroot "$rootfs" lsblk | grep -q "loop0"
chroot "$rootfs" partx --help | grep -iq "usage"
chroot "$rootfs" blkdiscard --help | grep -iq "usage"
chroot "$rootfs" blockdev --help | grep -iq "usage"
chroot "$rootfs" zramctl --help | grep -iq "usage"
