#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices i2c-tools_i2c-stub-from-dump)"

# end-to-end use needs the i2c-stub kernel module + /sys/bus/i2c/drivers/i2c-stub/
# which isn't available in a chroot.
chroot "$rootfs" /usr/sbin/i2c-stub-from-dump 2>&1 | grep -Fiq "usage: i2c-stub-from-dump"

# functional: feed a tiny dump into the 0x55 stub chip, read it back via
# i2cget. i2c-stub-from-dump itself shells out to i2cdetect (-l, to find the
# stub bus) and i2cset (to write registers), so both must be in rootfs2.
if ! stub_bus=$(./setup-i2c-stub 0x55) || [ -z "$stub_bus" ]; then
    echo "i2c-stub unavailable -- skipping functional test" >&2
    exit 0
fi

rootfs2="$(install-slices \
    i2c-tools_i2c-stub-from-dump \
    i2c-tools_i2cdetect \
    i2c-tools_i2cset \
    i2c-tools_i2cget \
)"
mkdir -p "$rootfs2/dev" "$rootfs2/sys" "$rootfs2/tmp"
mount --bind /dev "$rootfs2/dev"
mount --bind /sys "$rootfs2/sys"
trap "umount -l '$rootfs2/dev' '$rootfs2/sys' 2>/dev/null || true" EXIT

cat > "$rootfs2/tmp/dump.txt" <<'EOF'
00: 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff 00
EOF

chroot "$rootfs2" /usr/sbin/i2c-stub-from-dump 0x55 /tmp/dump.txt
chroot "$rootfs2" i2cget -y "$stub_bus" 0x55 0x00 | grep -Fq "0x11"
