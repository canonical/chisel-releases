#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libgcc libc

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "ppc64le" || "$arch" == "x86_64" ]]; then
    cross=true
elif [[ "$arch" == "s390x" ]]; then
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
        gcc-13-s390x-linux-gnu_gcc-13
        cpp-13-s390x-linux-gnu_cc1
        binutils-s390x-linux-gnu_assembler
        binutils-s390x-linux-gnu_linker
        libgcc-13-dev_core
        libc6-dev_core
    )
    rootfs="$(install-slices "${slices[@]}")"
    ln -s s390x-linux-gnu-gcc-13 "${rootfs}/usr/bin/gcc"
    ln -s s390x-linux-gnu-as "${rootfs}/usr/bin/as"
    ln -s s390x-linux-gnu-ld "${rootfs}/usr/bin/ld"

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
