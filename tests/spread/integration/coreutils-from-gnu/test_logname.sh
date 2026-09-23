#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_logname)"
chroot "$rootfs" logname --version
# NOTE: there is no login session inside the chroot
chroot "$rootfs" logname 2>&1 | grep -qE "no login name|root"
