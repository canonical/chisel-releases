#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuwhoami

rootfs="$(install-slices gnu-coreutils_whoami)"
chroot "$rootfs" gnuwhoami --version
# NOTE: w/out base-passwd there is no name for uid 0
chroot "$rootfs" gnuwhoami 2>&1 | grep -qE "root|cannot find name for user ID 0"
