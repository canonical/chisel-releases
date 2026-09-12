#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudir gnudircolors gnuls gnuvdir

rootfs="$(install-slices gnu-coreutils_directory-listing)"
cmds=(
    gnudir
    gnudircolors
    gnuls
    gnuvdir
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
