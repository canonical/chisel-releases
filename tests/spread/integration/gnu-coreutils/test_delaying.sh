#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusleep

rootfs="$(install-slices gnu-coreutils_delaying)"
cmds=(
    gnusleep
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
