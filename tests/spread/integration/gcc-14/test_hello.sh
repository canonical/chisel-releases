#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils

arch=$(uname -m)-linux-gnu
slices=(
    gcc-14-"${arch//_/-}"_gcc-14
    cpp-14-"${arch//_/-}"_cc1
    binutils-"${arch//_/-}"_assembler
    binutils-"${arch//_/-}"_linker
    libgcc-14-dev_core
    libc6-dev_core
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${arch}-gcc-14" "${rootfs}/usr/bin/gcc"
ln -s "${arch}-as" "${rootfs}/usr/bin/as"
ln -s "${arch}-ld" "${rootfs}/usr/bin/ld"

cat > "${rootfs}/hello.c" << EOF
#include <stdio.h>
int main() {
    printf("Hello from C!\n");
    return 0;
}
EOF
chroot "${rootfs}" gcc /hello.c -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from C!"
