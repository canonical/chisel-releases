#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_false-bin)"
chroot "$rootfs" false --version | grep -q "coreutils"
rc=0
chroot "$rootfs" false || rc=$?
test "$rc" = "1"
