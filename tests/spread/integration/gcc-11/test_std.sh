#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libgcc libc

arch=$(uname -m)
case "$arch" in
    x86_64)   triplet="x86_64-linux-gnu" ;;
    aarch64)  triplet="aarch64-linux-gnu" ;;
    ppc64le)  triplet="powerpc64le-linux-gnu" ;;
    s390x)    triplet="s390x-linux-gnu" ;;
    *)        echo "Unsupported architecture: $arch"; exit 1 ;;
esac

slices=(
    gcc-11_gcc-11
    libc6-dev_core
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${triplet}-gcc-11" "${rootfs}/usr/bin/gcc"

cp testfiles/test_std.c "${rootfs}/test_std.c"
cp testfiles/test_std.h "${rootfs}/test_std.h"

chroot "${rootfs}" gcc /test_std.c -o /test_std
chroot "${rootfs}" /test_std
