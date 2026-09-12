#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutee

rootfs="$(install-slices gnu-coreutils_redirection)"
cmds=(
    gnutee
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
