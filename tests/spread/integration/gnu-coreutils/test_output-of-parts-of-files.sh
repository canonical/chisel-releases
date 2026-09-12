#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucsplit gnuhead gnusplit gnutail

rootfs="$(install-slices gnu-coreutils_output-of-parts-of-files)"
cmds=(
    gnucsplit
    gnuhead
    gnusplit
    gnutail
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
