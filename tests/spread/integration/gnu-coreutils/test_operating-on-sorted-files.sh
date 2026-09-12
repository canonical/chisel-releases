#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucomm gnuptx gnushuf gnusort gnutsort gnuuniq

rootfs="$(install-slices gnu-coreutils_operating-on-sorted-files)"
cmds=(
    gnucomm
    gnuptx
    gnushuf
    gnusort
    gnutsort
    gnuuniq
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
