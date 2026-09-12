#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_stty)"
chroot "$rootfs" stty --version
chroot "$rootfs" stty < /dev/null 2>&1 | grep -q "Inappropriate ioctl for device"
# NOTE: script(1) gives stty a pty to read the settings of
script -qec "chroot '$rootfs' stty -a" /dev/null | grep -q "speed"
