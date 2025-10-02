#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs dumpmachine dumpversion dumpspecs

arch=$(uname -m)-linux-gnu
rootfs="$(install-slices gcc-14-"${arch//_/-}"_gcc-14)"
ln -s "${arch}-gcc-14" "${rootfs}/usr/bin/gcc"

dumpmachine=$(chroot "${rootfs}" gcc -dumpmachine)
test "$dumpmachine" = "$arch"
dumpversion=$(chroot "${rootfs}" gcc -dumpversion)
test "$dumpversion" = "14"

# shellcheck disable=SC2063
dumpspecs=$(chroot "${rootfs}" gcc -dumpspecs | grep '^*' | tr '\n' ' ')
expected_keys=("asm" "cc1" "cpp" "link" "lib")
for key in "${expected_keys[@]}"; do
    # shellcheck disable=SC2063
    echo "$dumpspecs" | grep -q "*${key}:"
done
