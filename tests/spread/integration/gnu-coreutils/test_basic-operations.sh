#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucp gnudd gnuinstall gnumv gnurm gnushred

rootfs="$(install-slices gnu-coreutils_basic-operations)"
cmds=(
    gnucp
    gnudd
    gnuinstall
    gnumv
    gnurm
    gnushred
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
