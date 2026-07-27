#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils

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
    cpp-11_cc1
    binutils_assembler
    binutils_linker
    libgcc-11-dev_core
    libc6-dev_core
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${triplet}-gcc-11" "${rootfs}/usr/bin/gcc"
ln -s "${triplet}-as" "${rootfs}/usr/bin/as"
ln -s "${triplet}-ld" "${rootfs}/usr/bin/ld"

cp testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc /hello.c -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from C!"
