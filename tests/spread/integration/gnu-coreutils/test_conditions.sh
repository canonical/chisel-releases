#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuexpr gnufalse gnutest gnutrue

rootfs="$(install-slices gnu-coreutils_conditions)"
cmds=(
    gnuexpr
    gnufalse
    gnutrue
    "gnu["
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
chroot "$rootfs" gnutest -n "coreutils"
