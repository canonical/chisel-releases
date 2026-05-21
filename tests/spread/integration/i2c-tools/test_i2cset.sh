#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cset)"

# writing a register needs /dev/i2c-* + a target chip. Limit to smoke checks.
chroot "$rootfs" i2cset -V 2>&1 | grep -Fi "i2cset"
chroot "$rootfs" i2cset 2>&1 | grep -Fiq "usage"
