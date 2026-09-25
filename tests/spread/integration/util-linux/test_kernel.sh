#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices util-linux_kernel)"

# NOTE: Accessing kernel dmesg is not permitted in LXD
chroot "$rootfs" dmesg --help
chroot "$rootfs" readprofile --help
