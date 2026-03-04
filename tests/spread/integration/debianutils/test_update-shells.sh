#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_update-shells)"

chroot "$rootfs" update-shells --help 2>&1
chroot "$rootfs" update-shells --version 2>&1

exit 99

