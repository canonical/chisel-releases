#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_pathchk)"
chroot "$rootfs" pathchk --version
chroot "$rootfs" pathchk -p valid_name
chroot "$rootfs" pathchk -p 'invalid*name' 2>&1 | grep -q "non-portable character"
