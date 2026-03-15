#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices apparmor_parser)"

chroot "$rootfs" apparmor_parser --help | grep -q "Usage: apparmor_parser"

# copy over profiles for testing
rootfs_profiles="$(install-slices apparmor_profiles)"
mkdir -p "$rootfs/etc/apparmor.d"
cp "$rootfs_profiles/etc/apparmor.d/Discord" "$rootfs/etc/apparmor.d/Discord"
cp -r "$rootfs_profiles/etc/apparmor.d/abi" "$rootfs/etc/apparmor.d/"
cp -r "$rootfs_profiles/etc/apparmor.d/tunables" "$rootfs/etc/apparmor.d/"

chroot "$rootfs" apparmor_parser --preprocess /etc/apparmor.d/Discord

chroot "$rootfs" apparmor_parser --names /etc/apparmor.d/Discord | grep -q "Discord"
