#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices apparmor_bins)"

chroot "$rootfs" apparmor_parser --help | grep -q "Usage: apparmor_parser"

chroot "$rootfs" apparmor_parser --preprocess /etc/apparmor.d/Discord

chroot "$rootfs" apparmor_parser --names /etc/apparmor.d/Discord | grep -q "Discord"
