#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusleep

rootfs="$(install-slices gnu-coreutils_sleep)"
chroot "$rootfs" gnusleep --version
chroot "$rootfs" gnusleep 0.1
