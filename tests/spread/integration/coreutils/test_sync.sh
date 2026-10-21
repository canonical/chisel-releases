#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_sync)"
chroot "$rootfs" sync --version
touch "$rootfs/test_file"
chroot "$rootfs" sync
chroot "$rootfs" sync test_file
