#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2ctransfer)"

# real transfers need /dev/i2c-* + a target chip which aren't available
# in a chroot.
chroot "$rootfs" i2ctransfer -V 2>&1 | grep -Fi "i2ctransfer"
chroot "$rootfs" i2ctransfer 2>&1 | grep -Fiq "usage"
