#!/bin/bash
#spellchecker: ignore rootfs 

rootfs="$(install-slices \
    util-linux_su-support \
    coreutils_whoami \
    dash_bins \
)"

# Create fake /etc/passwd
mkdir -p "$rootfs"/etc
echo "foo:!:1001:1001:Test user,,,:/tmp:/usr/bin/sh" >> "$rootfs"/etc/passwd
chmod 755 "$rootfs"

chroot "$rootfs" su foo -c whoami | grep -qx "foo"
chroot "$rootfs" runuser foo -c whoami | grep -qx "foo"
