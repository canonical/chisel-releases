#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnupathchk

rootfs="$(install-slices gnu-coreutils_pathchk)"
chroot "$rootfs" gnupathchk --version
chroot "$rootfs" gnupathchk -p valid_name
chroot "$rootfs" gnupathchk -p 'invalid*name' 2>&1 | grep -q "non-portable character"
