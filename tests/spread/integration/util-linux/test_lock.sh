#!/bin/bash
#spellchecker: ignore rootfs lslocks

rootfs="$(install-slices \
    util-linux_lock \
    dash_bins \
)"

mkdir "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount $rootfs/proc || true" EXIT

chroot "$rootfs" flock --help | grep -iq "usage"

SHELL="/usr/bin/sh" chroot "$rootfs" flock /my-lock lslocks | grep -q "/my-lock"
