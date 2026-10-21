#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_false)"
chroot "$rootfs" false --version | grep -q "coreutils"
rc=0
chroot "$rootfs" false || rc=$?
test "$rc" = "1"
