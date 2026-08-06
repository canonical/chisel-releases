#!/usr/bin/env bash
# spellchecker: ignore rootfs dumpmachine dumpversion dumpspecs

arch=$(uname -m)
case "$arch" in
    x86_64)   triplet="x86_64-linux-gnu" ;;
    aarch64)  triplet="aarch64-linux-gnu" ;;
    ppc64le)  triplet="powerpc64le-linux-gnu" ;;
    s390x)    triplet="s390x-linux-gnu" ;;
    *)        echo "Unsupported architecture: $arch"; exit 1 ;;
esac

rootfs="$(install-slices gcc-11_gcc-11)"
ln -s "${triplet}-gcc-11" "${rootfs}/usr/bin/gcc"

dumpmachine=$(chroot "${rootfs}" gcc -dumpmachine)
test "$dumpmachine" = "$triplet"
dumpversion=$(chroot "${rootfs}" gcc -dumpversion)
test "$dumpversion" = "11"

# shellcheck disable=SC2063
dumpspecs=$(chroot "${rootfs}" gcc -dumpspecs | grep '^*' | tr '\n' ' ')
expected_keys=("asm" "cc1" "cpp" "link" "lib")
for key in "${expected_keys[@]}"; do
    # shellcheck disable=SC2063
    echo "$dumpspecs" | grep -q "*${key}:"
done
