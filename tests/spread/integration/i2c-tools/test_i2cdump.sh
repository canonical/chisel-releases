#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cdump)"

# real register dumps need /dev/i2c-* + a peer chip. Limit to smoke checks.
chroot "$rootfs" i2cdump -V 2>&1 | grep -Fi "i2cdump"
chroot "$rootfs" i2cdump 2>&1 | grep -Fiq "usage"
