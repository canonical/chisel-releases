#!/bin/bash
#spellchecker: ignore rootfs 

rootfs="$(install-slices util-linux_tty)"

chroot "$rootfs" setterm --help | grep -iq "usage"
chroot "$rootfs" agetty --help | grep -iq "usage"
chroot "$rootfs" getty --help | grep -iq "usage"
