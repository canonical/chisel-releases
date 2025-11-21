#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libgcc libc

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" ]]; then
    cross=true
elif [[ "$arch" == "x86_64" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    slices=(
        gcc-14-x86-64-linux-gnu_gcc-14
        cpp-14-x86-64-linux-gnu_cc1
        binutils-x86-64-linux-gnu_assembler
        binutils-x86-64-linux-gnu_linker
        libgcc-14-dev_core
        libc6-dev_core
    )
    rootfs="$(install-slices "${slices[@]}")"
    ln -s "x86_64-linux-gnu-gcc-14" "${rootfs}/usr/bin/gcc"
    ln -s "x86_64-linux-gnu-as" "${rootfs}/usr/bin/as"
    ln -s "x86_64-linux-gnu-ld" "${rootfs}/usr/bin/ld"
else
    slices=(
        gcc-14-x86-64-linux-gnu_gcc-14
        cpp-14-x86-64-linux-gnu_cc1
        binutils-x86-64-linux-gnu_assembler
        binutils-x86-64-linux-gnu_linker
        libgcc-14-dev_core
        libc6-dev_core
    )
    rootfs="$(install-slices "${slices[@]}")"
    ln -s "x86_64-linux-gnu-gcc-14" "${rootfs}/usr/bin/gcc"
    ln -s "x86_64-linux-gnu-as" "${rootfs}/usr/bin/as"
    ln -s "x86_64-linux-gnu-ld" "${rootfs}/usr/bin/ld"
fi

cp test_std.c "${rootfs}/test_std.c"
cp test_std.h "${rootfs}/test_std.h"

if $cross; then
    # TODO: We do not have libgcc-14-dev-amd64-cross for cross compilation yet
    :
else
    chroot "${rootfs}" gcc /test_std.c -o /test_std
    chroot "${rootfs}" /test_std

    # try again with a bunch of C standards
    # for std in c99 c11 c17 c23; do
    #     rm -f "${rootfs}/test_std"
    #     chroot "${rootfs}" gcc -std="$std" -DSTD="$std" /test_std.c -o /test_std
    #     chroot "${rootfs}" /test_std
    # done
fi