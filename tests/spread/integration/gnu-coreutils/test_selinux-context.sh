#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchcon gnuruncon

rootfs="$(install-slices gnu-coreutils_selinux-context)"
cmds=(
    gnuchcon
    gnuruncon
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
