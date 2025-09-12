#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs

arch=$(uname -m)-linux-gnu
rootfs="$(install-slices gcc-14-"${arch//_/-}"_gcc-14)"
ln -s "${arch}-gcc-14" "${rootfs}/usr/bin/gcc"

# something like: Usage: gcc [options] file...
help=$(chroot "${rootfs}" gcc --help | head -n1)
echo "$help" | grep -q "Usage: gcc"

# something like: gcc (Ubuntu 14.2.0-19ubuntu2) 14.2.0
version=$(chroot "${rootfs}" gcc --version | head -n1)
echo "$version" | grep -q "gcc"
echo "$version" | grep -q "14."