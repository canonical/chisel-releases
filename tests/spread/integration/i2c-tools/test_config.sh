#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_config)"

# udev rule file has no logic of its own -- it's matched at runtime by udevd
# against /dev/i2c-* events, which won't fire in a chroot. Verify presence.
test -f "$rootfs"/usr/lib/udev/rules.d/60-i2c-tools.rules
