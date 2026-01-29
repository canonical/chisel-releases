#!/usr/bin/env bash
# spellchecker: ignore rootfs dumpmachine dumpversion dumpspecs

rootfs="$(install-slices gcc-aarch64-linux-gnu_gcc)"
ln -s "aarch64-linux-gnu-gcc" "${rootfs}/usr/bin/gcc"

dumpmachine=$(chroot "${rootfs}" gcc -dumpmachine)
test "$dumpmachine" = "aarch64-linux-gnu"
dumpversion=$(chroot "${rootfs}" gcc -dumpversion)
test "$dumpversion" = "15"

# shellcheck disable=SC2063
dumpspecs=$(chroot "${rootfs}" gcc -dumpspecs | grep '^*' | tr '\n' ' ')
expected_keys=("asm" "cc1" "cpp" "link" "lib")
for key in "${expected_keys[@]}"; do
    # shellcheck disable=SC2063
    echo "$dumpspecs" | grep -q "*${key}:"
done
