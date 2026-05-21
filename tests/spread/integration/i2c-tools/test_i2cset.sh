#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cset)"

# writing a register needs /dev/i2c-* + a target chip which aren't available
# in a chroot.
chroot "$rootfs" i2cset -V 2>&1 | grep -Fi "i2cset"
chroot "$rootfs" i2cset 2>&1 | grep -Fiq "usage"

# functional: write a byte to 0x53 then read it back via i2cget.
if ! stub_bus=$(./setup-i2c-stub 0x53) || [ -z "$stub_bus" ]; then
    echo "i2c-stub unavailable -- skipping functional test" >&2
    exit 0
fi

rootfs2="$(install-slices i2c-tools_i2cset i2c-tools_i2cget)"
mkdir -p "$rootfs2/dev" "$rootfs2/sys"
mount --bind /dev "$rootfs2/dev"
mount --bind /sys "$rootfs2/sys"
trap "umount -l '$rootfs2/dev' '$rootfs2/sys' 2>/dev/null || true" EXIT

chroot "$rootfs2" i2cset -y "$stub_bus" 0x53 0x10 0xab
chroot "$rootfs2" i2cget -y "$stub_bus" 0x53 0x10 | grep -Fq "0xab"
