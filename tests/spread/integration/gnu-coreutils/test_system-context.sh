#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuarch gnudate gnuhostid gnunproc gnuuname

rootfs="$(install-slices gnu-coreutils_system-context)"
cmds=(
    gnuarch
    gnudate
    gnuhostid
    gnunproc
    gnuuname
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
