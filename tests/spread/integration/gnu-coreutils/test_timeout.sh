#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuecho gnusleep gnutimeout

rootfs="$(install-slices gnu-coreutils_echo gnu-coreutils_sleep gnu-coreutils_timeout)"
chroot "$rootfs" gnutimeout --version
test "$(chroot "$rootfs" gnutimeout 1 gnuecho "Done")" = "Done"
rc=0
chroot "$rootfs" gnutimeout 0.1 gnusleep 5 || rc=$?
test "$rc" = "124"
