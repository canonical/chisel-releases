#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2ctransfer)"

# real transfers need /dev/i2c-* + a target chip. Limit to smoke checks.
chroot "$rootfs" i2ctransfer -V 2>&1 | grep -Fi "i2ctransfer"
chroot "$rootfs" i2ctransfer 2>&1 | grep -Fiq "usage"
