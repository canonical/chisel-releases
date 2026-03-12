#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_which)"
chroot "$rootfs" which sh | grep -q "/bin/sh"
