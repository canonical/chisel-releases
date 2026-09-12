#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_modified-command-invocation)"
cmds=(
    /usr/sbin/chroot
    env
    nice
    nohup
    stdbuf
    timeout
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
