#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cdump)"

# real register dumps need /dev/i2c-* + a peer chip which aren't available
# in a chroot.
chroot "$rootfs" i2cdump -V 2>&1 | grep -Fi "i2cdump"
chroot "$rootfs" i2cdump 2>&1 | grep -Fiq "usage"

# functional: dump our 0x51 stub chip (all registers default to zero).
if ! stub_bus=$(./setup-i2c-stub 0x51) || [ -z "$stub_bus" ]; then
    echo "i2c-stub unavailable -- skipping functional test" >&2
    exit 0
fi

rootfs2="$(install-slices i2c-tools_i2cdump)"
mkdir -p "$rootfs2/dev" "$rootfs2/sys"
mount --bind /dev "$rootfs2/dev"
mount --bind /sys "$rootfs2/sys"
trap "umount -l '$rootfs2/dev' '$rootfs2/sys' 2>/dev/null || true" EXIT

chroot "$rootfs2" i2cdump -y "$stub_bus" 0x51 2>&1 | grep -Fq "00 00 00 00"
