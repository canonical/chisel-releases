#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libgcc libc

arch=$(uname -m)
cross=false
if [[ "$arch" == "x86_64" ]]; then
    cross=true
elif [[ "$arch" == "aarch64" ]]; then
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
        gcc-15-aarch64-linux-gnu_gcc-15
        cpp-15-aarch64-linux-gnu_cc1
        binutils-aarch64-linux-gnu_assembler
        binutils-aarch64-linux-gnu_linker
        libgcc-15-dev_core
        libc6-dev_core
    )
    rootfs="$(install-slices "${slices[@]}")"
    ln -s aarch64-linux-gnu-gcc-15 "${rootfs}/usr/bin/gcc"
    ln -s aarch64-linux-gnu-as "${rootfs}/usr/bin/as"
    ln -s aarch64-linux-gnu-ld "${rootfs}/usr/bin/ld"

    cp testfiles/test_std.c "${rootfs}/test_std.c"
    cp testfiles/test_std.h "${rootfs}/test_std.h"

    chroot "${rootfs}" gcc /test_std.c -o /test_std
    chroot "${rootfs}" /test_std

    # try again with a bunch of C standards
    # for std in c99 c11 c17 c23; do
    #     rm -f "${rootfs}/test_std"
    #     chroot "${rootfs}" gcc -std="$std" -DSTD="$std" /test_std.c -o /test_std
    #     chroot "${rootfs}" /test_std
    # done
fi
