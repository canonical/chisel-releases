#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchroot gnuenv gnunice gnunohup gnustdbuf gnutimeout

rootfs="$(install-slices gnu-coreutils_modified-command-invocation)"
cmds=(
    /usr/sbin/gnuchroot
    gnuenv
    gnunice
    gnunohup
    gnustdbuf
    gnutimeout
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
