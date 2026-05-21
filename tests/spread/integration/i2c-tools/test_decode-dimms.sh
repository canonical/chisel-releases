#!/bin/bash
# spellchecker: ignore rootfs dimms

rootfs="$(install-slices i2c-tools_decode-dimms)"

# real output needs DIMM eeproms exposed via /sys/bus/i2c/devices/*/eeprom which
# isn't available in a chroot. Running with no input reaches the sysfs-scan path
# (proving shebang + `use`d modules load) and prints the no-eeprom message.
chroot "$rootfs" /usr/bin/decode-dimms 2>&1 | grep -Fiq "no eeprom found"
