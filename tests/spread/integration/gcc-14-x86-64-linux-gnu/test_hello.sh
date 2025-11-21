#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils

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

cat > "${rootfs}/hello.c" << EOF
#include <stdio.h>
int main() {
    printf("Hello from C!\n");
    return 0;
}
EOF

if $cross; then
    # TODO: We do not have libgcc-14-dev-amd64-cross for cross compilation yet
    :
else
    chroot "${rootfs}" gcc /hello.c -o /hello
    chroot "${rootfs}" /hello | grep -q "Hello from C!"
fi
