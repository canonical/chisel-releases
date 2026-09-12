#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_conditions)"
cmds=(
    expr
    false
    true
    "["
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
chroot "$rootfs" test -n "coreutils"
