#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnubase32 gnubase64 gnubasenc gnucat gnunl gnuod gnutac

rootfs="$(install-slices gnu-coreutils_output-of-entire-files)"
cmds=(
    gnubase32
    gnubase64
    gnubasenc
    gnucat
    gnunl
    gnuod
    gnutac
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
