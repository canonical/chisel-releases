#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnufalse

rootfs="$(install-slices gnu-coreutils_false)"
chroot "$rootfs" gnufalse --version | grep -q "coreutils"
rc=0
chroot "$rootfs" gnufalse || rc=$?
test "$rc" = "1"
