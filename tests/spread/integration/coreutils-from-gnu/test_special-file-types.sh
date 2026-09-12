#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_special-file-types)"
cmds=(
    link
    ln
    mkdir
    mkfifo
    mknod
    readlink
    rmdir
    unlink
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
