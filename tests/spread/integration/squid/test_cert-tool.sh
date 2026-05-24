#!/usr/bin/env bash
# spellchecker: ignore rootfs
rootfs="$(install-slices squid_cert-tool base-files_base)"


# Setup
mkdir -p "$rootfs/dev"
mount --rbind /dev "$rootfs/dev"
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Cleanup function
cleanup() {
    umount -l "$rootfs/dev" || true
    timeout 10 bash -c "while mountpoint -q '$rootfs/dev'; do sleep 0.5; done"
    rm -rf "$rootfs"
}
trap cleanup EXIT

# Test cert_tool
chroot "$rootfs" /usr/lib/squid/cert_tool ubuntu.com 443

# Check that NSS DB files exist
test -f "$rootfs/cert9.db"
test -f "$rootfs/key4.db"

cleanup
