#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnubasename gnudirname gnumktemp gnupathchk gnurealpath

rootfs="$(install-slices gnu-coreutils_file-name-manipulation)"
cmds=(
    gnubasename
    gnudirname
    gnumktemp
    gnupathchk
    gnurealpath
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
