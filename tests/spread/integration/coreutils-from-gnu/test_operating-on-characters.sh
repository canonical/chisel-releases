#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_operating-on-characters)"
cmds=(
    expand
    tr
    unexpand
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
