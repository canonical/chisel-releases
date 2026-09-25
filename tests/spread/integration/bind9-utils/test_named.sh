#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9-utils_named bind9_config bind9_data)"

# Make fake /dev/null and mount /proc
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

# Setup
mkdir -p "${rootfs}/etc/bind"
cp db.test.local "${rootfs}/etc/bind/db.test.local"

# Test named-checkzone with the test zone file
chroot $rootfs named-checkzone test.local /etc/bind/db.test.local | grep "OK"

# Test named-compilezone with the test zone file (generates .nzf file)
chroot $rootfs named-compilezone -o /etc/bind/db.test.local.nzf test.local /etc/bind/db.test.local | grep "OK"
cat "${rootfs}/etc/bind/db.test.local.nzf" | grep "ns1.test.local." | grep "IN A" | grep "127.0.0.1"

# Test named-checkconf (bringing config file from bind9_config slice and cache from bind9_data slice)
chroot $rootfs named-checkconf -p | grep "directory \"/var/cache/bind\";"