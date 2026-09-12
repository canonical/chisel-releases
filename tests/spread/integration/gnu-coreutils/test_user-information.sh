#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnugroups gnuid gnulogname gnupinky gnuusers gnuwho gnuwhoami

rootfs="$(install-slices gnu-coreutils_user-information)"
cmds=(
    gnugroups
    gnuid
    gnulogname
    gnupinky
    gnuusers
    gnuwho
    gnuwhoami
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
