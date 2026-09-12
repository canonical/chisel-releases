#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnulink gnuln gnumkdir gnumkfifo gnumknod gnureadlink gnurmdir gnuunlink

rootfs="$(install-slices gnu-coreutils_special-file-types)"
cmds=(
    gnulink
    gnuln
    gnumkdir
    gnumkfifo
    gnumknod
    gnureadlink
    gnurmdir
    gnuunlink
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
