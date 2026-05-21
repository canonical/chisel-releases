#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cget)"

# reading a register needs /dev/i2c-* + a target chip which aren't available
# in a chroot.
chroot "$rootfs" i2cget -V 2>&1 | grep -Fi "i2cget"
chroot "$rootfs" i2cget 2>&1 | grep -Fiq "usage"
