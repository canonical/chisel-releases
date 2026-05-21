#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2c-stub-from-dump)"

# end-to-end use needs the i2c-stub kernel module + /sys/bus/i2c/drivers/i2c-stub/
# which isn't available in a chroot. Invoking with no args reaches the arg-parse
# stage (proving shebang + `use`d modules load) and prints usage to stderr.
chroot "$rootfs" /usr/sbin/i2c-stub-from-dump 2>&1 | grep -Fiq "usage: i2c-stub-from-dump"
