#!/usr/bin/env bash
# spellchecker: ignore rootfs
rootfs="$(install-slices squid_cert base-files_base)"

# Setup
mkdir -p "${rootfs}/dev"
mount --rbind /dev "${rootfs}/dev"
mknod -m 666 "$rootfs/dev/random" c 1 8
mknod -m 666 "$rootfs/dev/urandom" c 1 9
cp /etc/resolv.conf "${rootfs}/etc/resolv.conf"

# Test cert_tool
chroot "$rootfs" /usr/lib/squid/cert_tool ubuntu.com 443

# Check that NSS DB files exist
test -f "$rootfs/cert9.db"
test -f "$rootfs/key4.db"
