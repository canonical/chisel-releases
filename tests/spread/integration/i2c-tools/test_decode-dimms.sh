#!/bin/bash
# spellchecker: ignore rootfs dimms

rootfs="$(install-slices i2c-tools_decode-dimms)"

# real output needs DIMM eeproms exposed via /sys/bus/i2c/devices/*/eeprom
# which isn't available in a chroot.
chroot "$rootfs" /usr/bin/decode-dimms 2>&1 | grep -Fiq "no eeprom found"
