#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucut gnujoin gnupaste

rootfs="$(install-slices gnu-coreutils_operating-on-fields)"
cmds=(
    gnucut
    gnujoin
    gnupaste
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
