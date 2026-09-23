#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuuname

rootfs="$(install-slices gnu-coreutils_uname)"
chroot "$rootfs" gnuuname --version
test "$(chroot "$rootfs" gnuuname -s)" = "Linux"
test "$(chroot "$rootfs" gnuuname -m)" = "$(uname -m)"
