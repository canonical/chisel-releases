#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuecho gnuprintf gnuyes

rootfs="$(install-slices gnu-coreutils_printing-text)"
cmds=(
    gnuecho
    gnuprintf
    gnuyes
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
