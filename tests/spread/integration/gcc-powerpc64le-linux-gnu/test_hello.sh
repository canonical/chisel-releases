#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils

arch=$(uname -m)
cross=false
if [[ "$arch" == "x86_64" || "$arch" == "aarch64" || "$arch" == "s390x" ]]; then
    cross=true
elif [[ "$arch" == "ppc64le" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    # TODO: We do not have libgcc-15-dev-amd64-cross for cross compilation yet
    :
else
    slices=(
        gcc-powerpc64le-linux-gnu_gcc
        cpp-15-powerpc64le-linux-gnu_cc1
        binutils-powerpc64le-linux-gnu_assembler
        binutils-powerpc64le-linux-gnu_linker
        libgcc-15-dev_core
        libc6-dev_core
    )
    rootfs="$(install-slices "${slices[@]}")"
    ln -s powerpc64le-linux-gnu-gcc "${rootfs}/usr/bin/gcc"
    ln -s powerpc64le-linux-gnu-as "${rootfs}/usr/bin/as"
    ln -s powerpc64le-linux-gnu-ld "${rootfs}/usr/bin/ld"

    cp testfiles/hello.c "${rootfs}/hello.c"

    chroot "${rootfs}" gcc /hello.c -o /hello
    chroot "${rootfs}" /hello | grep -q "Hello from C!"
fi
