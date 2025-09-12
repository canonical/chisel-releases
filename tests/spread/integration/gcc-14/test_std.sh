#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils libgcc libc

arch=$(uname -m)-linux-gnu
slices=(
    gcc-14-"${arch//_/-/}"_gcc-14
    cpp-14-"${arch//_/-/}"_cc1
    binutils-"${arch//_/-/}"_assembler
    binutils-"${arch//_/-/}"_linker
    libgcc-14-dev_libgcc
    libc6-dev_posix-libs
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${arch}-gcc-14" "${rootfs}/usr/bin/gcc"
ln -s "${arch}-as" "${rootfs}/usr/bin/as"
ln -s "${arch}-ld" "${rootfs}/usr/bin/ld"

cp test_std.c "${rootfs}/test_std.c"
cp test_std.h "${rootfs}/test_std.h"
chroot "${rootfs}" gcc /test_std.c -o /test_std
chroot "${rootfs}" /test_std

# try again with a bunch of C standards
# for std in c99 c11 c17 c23; do
#     rm -f "${rootfs}/test_std"
#     chroot "${rootfs}" gcc -std="$std" -DSTD="$std" /test_std.c -o /test_std
#     chroot "${rootfs}" /test_std
# done