#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_true-bin)"
chroot "$rootfs" true --version
chroot "$rootfs" true
