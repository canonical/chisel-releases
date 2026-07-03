#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils

arch=$(uname -m)
cross=false
if [[ "$arch" == "x86_64" || "$arch" == "amd64" || "$arch" == "ppc64le" ]]; then
    cross=true
elif [[ "$arch" == "s390x" ]]; then
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
        gcc-15-s390x-linux-gnu_gcc-15
        cpp-15-s390x-linux-gnu_cc1
        binutils-s390x-linux-gnu_assembler
        binutils-s390x-linux-gnu_linker
        libgcc-15-dev_core
        libc6-dev_core
    )
    rootfs="$(install-slices "${slices[@]}")"
    ln -s s390x-linux-gnu-gcc-15 "${rootfs}/usr/bin/gcc"
    ln -s s390x-linux-gnu-as "${rootfs}/usr/bin/as"
    ln -s s390x-linux-gnu-ld "${rootfs}/usr/bin/ld"

    cp testfiles/hello.c "${rootfs}/hello.c"

    chroot "${rootfs}" gcc /hello.c -o /hello
    chroot "${rootfs}" /hello | grep -q "Hello from C!"
fi
