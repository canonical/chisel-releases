#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_operating-on-sorted-files)"
cmds=(
    comm
    ptx
    shuf
    sort
    tsort
    uniq
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
