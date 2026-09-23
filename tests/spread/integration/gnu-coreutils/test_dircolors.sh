#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudircolors

rootfs="$(install-slices gnu-coreutils_dircolors)"
chroot "$rootfs" gnudircolors --version
chroot "$rootfs" gnudircolors -b | grep -q "^LS_COLORS="
chroot "$rootfs" gnudircolors -p | grep -q "^DIR "
