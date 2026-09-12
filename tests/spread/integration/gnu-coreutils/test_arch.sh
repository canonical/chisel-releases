#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuarch

rootfs="$(install-slices gnu-coreutils_arch)"
chroot "$rootfs" gnuarch --version
test "$(chroot "$rootfs" gnuarch)" = "$(uname -m)"
