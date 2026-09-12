#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuexpand gnutr gnuunexpand

rootfs="$(install-slices gnu-coreutils_operating-on-characters)"
cmds=(
    gnuexpand
    gnutr
    gnuunexpand
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
