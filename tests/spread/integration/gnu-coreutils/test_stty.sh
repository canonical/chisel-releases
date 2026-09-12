#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnustty

rootfs="$(install-slices gnu-coreutils_stty)"
chroot "$rootfs" gnustty --version
chroot "$rootfs" gnustty < /dev/null 2>&1 | grep -q "Inappropriate ioctl for device"
# NOTE: script(1) gives stty a pty to read the settings of
script -qec "chroot '$rootfs' gnustty -a" /dev/null | grep -q "speed"
