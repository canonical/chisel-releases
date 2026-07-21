#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libc crti crtn libbfd libctf libopcodes
set -euo pipefail

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "x86_64" || "$arch" == "ppc64le" ]]; then
    cross=true
elif [[ "$arch" == "s390x" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    slices=(
        binutils-s390x-linux-gnu_assembler
        binutils-s390x-linux-gnu_cross-libbfd
        binutils-s390x-linux-gnu_cross-libopcodes
    )

    rootfs_as="$(install-slices "${slices[@]}")"
    ln -s "s390x-linux-gnu-as" "$rootfs_as/usr/bin/as"

    slices=(
        binutils-s390x-linux-gnu_linker
        binutils-s390x-linux-gnu_cross-libbfd
        binutils-s390x-linux-gnu_cross-libctf
    )
    
    rootfs_ld="$(install-slices "${slices[@]}")"
    ln -s "s390x-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
else
    rootfs_as="$(install-slices \
        binutils-s390x-linux-gnu_assembler \
    )"
    ln -s "s390x-linux-gnu-as" "$rootfs_as/usr/bin/as"

    # need libc6-dev_core for linking with libc
    rootfs_ld="$(install-slices \
        binutils-s390x-linux-gnu_linker \
        libc6-dev_core \
    )"
    ln -s "s390x-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
fi

cp "hello-s390x-linux-gnu.S" "$rootfs_as/hello.S"
chroot "$rootfs_as" as hello.S -o hello.o
mv "$rootfs_as/hello.o" "$rootfs_ld/hello.o"

if $cross; then
    # TODO: This should compile but we don't have libc6-dev for cross compilation yet
    #       For now a cut-down version which is expected to fail due to no libc linking
    # chroot "$rootfs_ld" ld hello.o -o hello \
    #     -dynamic-linker "${linker_lib}" \
    #     -lc \
    #     /usr/lib/"$other"/crt1.o \
    #     /usr/lib/"$other"/crti.o \
    #     /usr/lib/"$other"/crtn.o
    (chroot "$rootfs_ld" ld hello.o -o hello 2>&1 || true) | grep -q "cannot find entry symbol _start"
else
    chroot "$rootfs_ld" ld hello.o -o hello \
        -lc \
        /usr/lib/s390x-linux-gnu/crt1.o \
        /usr/lib/s390x-linux-gnu/crti.o \
        /usr/lib/s390x-linux-gnu/crtn.o
    chroot "$rootfs_ld" ./hello | grep "Hello world!" || exit 1
fi
