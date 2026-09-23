#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnulogname

rootfs="$(install-slices gnu-coreutils_logname)"
chroot "$rootfs" gnulogname --version
# NOTE: there is no login session inside the chroot
chroot "$rootfs" gnulogname 2>&1 | grep -qE "no login name|root"
