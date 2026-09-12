#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_hostid)"
chroot "$rootfs" hostid --version
chroot "$rootfs" hostid | grep -qE "^[0-9a-f]{8}$"
