#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils ischroot

rootfs="$(install-slices debianutils_ischroot)"
chroot "$rootfs" ischroot --help | grep -q "Usage: ischroot"
chroot "$rootfs" ischroot --version | grep -q "Debian ischroot"

chroot "$rootfs" ischroot --default-false && exit 1
chroot "$rootfs" ischroot --default-true || exit 1

