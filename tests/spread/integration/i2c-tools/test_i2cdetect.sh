#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2cdetect)"

# deeper testing (bus scan) requires /dev/i2c-* devices which aren't available
# in a chroot.
chroot "$rootfs" i2cdetect -V 2>&1 | grep -Fi "i2cdetect"
chroot "$rootfs" i2cdetect 2>&1 | grep -Fiq "usage"

# functional: mock an i2c bus via i2c-stub and scan it. skips on environments
# where i2c-stub can't be loaded (e.g. local docker spread w/out /lib/modules).
if ! stub_bus=$(./setup-i2c-stub 0x50) || [ -z "$stub_bus" ]; then
    echo "i2c-stub unavailable -- skipping functional test" >&2
    exit 0
fi

rootfs2="$(install-slices i2c-tools_i2cdetect)"
mkdir -p "$rootfs2/dev" "$rootfs2/sys"
mount --bind /dev "$rootfs2/dev"
mount --bind /sys "$rootfs2/sys"
trap "umount -l '$rootfs2/dev' '$rootfs2/sys' 2>/dev/null || true" EXIT

# table row 50: should list chip 0x50 in column 0
chroot "$rootfs2" i2cdetect -y "$stub_bus" 2>&1 | grep -Fq " 50 "
