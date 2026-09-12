#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnufactor gnunumfmt gnuseq

rootfs="$(install-slices gnu-coreutils_numeric-operations)"
cmds=(
    gnufactor
    gnunumfmt
    gnuseq
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
