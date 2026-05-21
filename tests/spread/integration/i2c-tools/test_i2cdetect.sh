#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cdetect)"

# deeper testing (bus scan) requires /dev/i2c-* devices which aren't available
# in a chroot.
chroot "$rootfs" i2cdetect -V 2>&1 | grep -Fi "i2cdetect"
chroot "$rootfs" i2cdetect 2>&1 | grep -Fiq "usage"
