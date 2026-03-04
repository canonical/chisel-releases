#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_add-shell)"

chroot "$rootfs" add-shell --help 2>&1
chroot "$rootfs" add-shell --version 2>&1

exit 99

