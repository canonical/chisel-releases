#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuhostid

rootfs="$(install-slices gnu-coreutils_hostid)"
chroot "$rootfs" gnuhostid --version
chroot "$rootfs" gnuhostid | grep -qE "^[0-9a-f]{8}$"
