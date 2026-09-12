#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutrue

rootfs="$(install-slices gnu-coreutils_true)"
chroot "$rootfs" gnutrue --version
chroot "$rootfs" gnutrue
