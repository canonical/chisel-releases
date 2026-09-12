#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudf gnudu gnustat gnusync gnutruncate

rootfs="$(install-slices gnu-coreutils_file-space-usage)"
cmds=(
    gnudf
    gnudu
    gnustat
    gnusync
    gnutruncate
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
