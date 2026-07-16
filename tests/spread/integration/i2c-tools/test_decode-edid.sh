#!/bin/bash
# spellchecker: ignore rootfs edid

rootfs="$(install-slices i2c-tools_decode-edid)"

# real decoding needs an EDID eeprom on the i2c bus which isn't available
# in a chroot.
chroot "$rootfs" /usr/bin/decode-edid 2>&1 | grep -Fiq "edid eeprom not found"
