#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_tty)"
chroot "$rootfs" tty --version
rc=0
out="$(chroot "$rootfs" tty < /dev/null)" || rc=$?
test "$rc" = "1"
test "$out" = "not a tty"
