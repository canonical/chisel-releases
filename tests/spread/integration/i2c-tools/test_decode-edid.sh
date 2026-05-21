#!/bin/bash
# spellchecker: ignore rootfs edid

rootfs="$(install-slices i2c-tools_decode-edid)"

# real decoding needs an EDID eeprom on the i2c bus which isn't available in a
# chroot. Running with no input reaches the sysfs-scan path (proving shebang +
# `use`d modules load) and prints the not-found message.
chroot "$rootfs" /usr/bin/decode-edid 2>&1 | grep -Fiq "edid eeprom not found"
