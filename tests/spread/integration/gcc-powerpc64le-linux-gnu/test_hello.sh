#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "s390x" || "$arch" == "x86_64" ]]; then
    cross=true
elif [[ "$arch" == "ppc64le" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    # TODO: We do not have libgcc-13-dev-cross for cross compilation yet
    :
else
    slices=(
        gcc-powerpc64le-linux-gnu_gcc
        cpp-13-powerpc64le-linux-gnu_cc1
        binutils-powerpc64le-linux-gnu_assembler
        binutils-powerpc64le-linux-gnu_linker
        libgcc-13-dev_core
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
