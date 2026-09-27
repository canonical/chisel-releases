#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_dircolors)"
chroot "$rootfs" dircolors --version
chroot "$rootfs" dircolors -b | grep -q "^LS_COLORS="
chroot "$rootfs" dircolors -p | grep -q "^DIR "
