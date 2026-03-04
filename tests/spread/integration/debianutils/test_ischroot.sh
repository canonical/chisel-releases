#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils ischroot

rootfs="$(install-slices debianutils_ischroot)"
chroot "${rootfs}" ischroot --version | grep -q "Debian ischroot"
