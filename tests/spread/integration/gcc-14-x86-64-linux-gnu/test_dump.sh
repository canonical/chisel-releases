#!/usr/bin/env bash
# spellchecker: ignore rootfs dumpmachine dumpversion dumpspecs

rootfs="$(install-slices gcc-14-x86-64-linux-gnu_gcc-14)"
ln -s "x86_64-linux-gnu-gcc-14" "${rootfs}/usr/bin/gcc"

dumpmachine=$(chroot "${rootfs}" gcc -dumpmachine)
test "$dumpmachine" = "x86_64-linux-gnu"
dumpversion=$(chroot "${rootfs}" gcc -dumpversion)
test "$dumpversion" = "14"

# shellcheck disable=SC2063
dumpspecs=$(chroot "${rootfs}" gcc -dumpspecs | grep '^*' | tr '\n' ' ')
expected_keys=("asm" "cc1" "cpp" "link" "lib")
for key in "${expected_keys[@]}"; do
    # shellcheck disable=SC2063
    echo "$dumpspecs" | grep -q "*${key}:"
done
