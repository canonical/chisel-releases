#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutty

rootfs="$(install-slices gnu-coreutils_tty)"
chroot "$rootfs" gnutty --version
rc=0
out="$(chroot "$rootfs" gnutty < /dev/null)" || rc=$?
test "$rc" = "1"
test "$out" = "not a tty"
