#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_whoami)"
chroot "$rootfs" whoami --version
# NOTE: w/out base-passwd there is no name for uid 0
chroot "$rootfs" whoami 2>&1 | grep -qE "root|cannot find name for user ID 0"
