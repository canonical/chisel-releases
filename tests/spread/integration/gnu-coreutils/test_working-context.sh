#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuprintenv gnupwd gnustty gnutty

rootfs="$(install-slices gnu-coreutils_working-context)"
cmds=(
    gnuprintenv
    gnupwd
    gnustty
    gnutty
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
