#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices gcc-aarch64-linux-gnu_gcc)"
ln -s "aarch64-linux-gnu-gcc" "${rootfs}/usr/bin/gcc"

# something like: Usage: gcc [options] file...
help=$(chroot "${rootfs}" gcc --help | head -n1)
echo "$help" | grep -q "Usage: gcc"

# something like: gcc (Ubuntu 15.2.0-19ubuntu2) 15.2.0
version=$(chroot "${rootfs}" gcc --version | head -n1)
echo "$version" | grep -q "gcc"
echo "$version" | grep -q "15."
