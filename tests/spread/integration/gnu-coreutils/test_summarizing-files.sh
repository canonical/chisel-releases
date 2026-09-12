#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnub2sum gnucksum gnumd5sum gnusha1sum gnusha224sum gnusha256sum gnusha384sum gnusha512sum gnusum gnuwc

rootfs="$(install-slices gnu-coreutils_summarizing-files)"
cmds=(
    gnub2sum
    gnucksum
    gnumd5sum
    gnusha1sum
    gnusha224sum
    gnusha256sum
    gnusha384sum
    gnusha512sum
    gnusum
    gnuwc
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
