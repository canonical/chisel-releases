#!/bin/bash
# spellchecker: ignore rootfs vaio

rootfs="$(install-slices i2c-tools_decode-vaio)"

# real decoding needs a Sony Vaio eeprom on the i2c bus which isn't available
# in a chroot.
chroot "$rootfs" /usr/bin/decode-vaio 2>&1 | grep -Fiq "vaio eeprom not found"
