#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils installkernel

rootfs="$(install-slices debianutils_installkernel)"

chroot "$rootfs" installkernel --help 2>&1
chroot "$rootfs" installkernel --version 2>&1

exit 99

