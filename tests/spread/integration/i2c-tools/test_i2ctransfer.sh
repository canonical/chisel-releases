#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2ctransfer)"

# real transfers need /dev/i2c-* + a target chip which aren't available
# in a chroot.
chroot "$rootfs" i2ctransfer -V 2>&1 | grep -Fi "i2ctransfer"
chroot "$rootfs" i2ctransfer 2>&1 | grep -Fiq "usage"

# functional: write+read via a single i2ctransfer pipeline against 0x54.
if ! stub_bus=$(./setup-i2c-stub 0x54) || [ -z "$stub_bus" ]; then
    echo "i2c-stub unavailable -- skipping functional test" >&2
    exit 0
fi

rootfs2="$(install-slices i2c-tools_i2ctransfer)"
mkdir -p "$rootfs2/dev" "$rootfs2/sys"
mount --bind /dev "$rootfs2/dev"
mount --bind /sys "$rootfs2/sys"
trap "umount -l '$rootfs2/dev' '$rootfs2/sys' 2>/dev/null || true" EXIT

chroot "$rootfs2" i2ctransfer -y "$stub_bus" w2@0x54 0x10 0x77
chroot "$rootfs2" i2ctransfer -y "$stub_bus" w1@0x54 0x10 r1@0x54 | grep -Fq "0x77"
