#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_config)"

# TODO(lczyk): this is only the udev rule. it can be better tested (e.g. via
# udevadm verify) once we have udev slices.
test -f "$rootfs"/usr/lib/udev/rules.d/60-i2c-tools.rules
