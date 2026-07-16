#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cget)"

# reading a register needs /dev/i2c-* + a target chip which aren't available
# in a chroot.
chroot "$rootfs" i2cget -V 2>&1 | grep -Fi "i2cget"
chroot "$rootfs" i2cget 2>&1 | grep -Fiq "usage"

# functional: seed register on 0x52 via i2cset, read it back via i2cget.
if ! stub_bus=$(./setup-i2c-stub 0x52) || [ -z "$stub_bus" ]; then
    echo "i2c-stub unavailable -- skipping functional test" >&2
    exit 0
fi

rootfs2="$(install-slices i2c-tools_i2cget i2c-tools_i2cset)"
mkdir -p "$rootfs2/dev" "$rootfs2/sys"
mount --bind /dev "$rootfs2/dev"
mount --bind /sys "$rootfs2/sys"
trap "umount -l '$rootfs2/dev' '$rootfs2/sys' 2>/dev/null || true" EXIT

chroot "$rootfs2" i2cset -y "$stub_bus" 0x52 0x10 0x42
chroot "$rootfs2" i2cget -y "$stub_bus" 0x52 0x10 | grep -Fq "0x42"
