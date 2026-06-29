#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices squid_cert-tool base-files_base)"

# Setup
mkdir -p "$rootfs/dev"
mount --rbind /dev "$rootfs/dev"
mount --make-rslave "$rootfs/dev"
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

trap cleanup EXIT

# Test cert_tool
chroot "$rootfs" /usr/lib/squid/cert_tool ubuntu.com 443

# Check that NSS DB files exist
test -f "$rootfs/cert9.db"
test -f "$rootfs/key4.db"

cleanup
