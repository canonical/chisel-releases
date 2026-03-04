#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_remove-shell)"

chroot "$rootfs" remove-shell --help 2>&1
chroot "$rootfs" remove-shell --version 2>&1

exit 99

