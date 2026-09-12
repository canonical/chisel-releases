#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnufmt gnufold gnupr

rootfs="$(install-slices gnu-coreutils_formatting-file-contents)"
cmds=(
    gnufmt
    gnufold
    gnupr
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
