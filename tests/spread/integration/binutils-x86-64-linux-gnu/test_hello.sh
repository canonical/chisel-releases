#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libc crti crtn libbfd libctf libopcodes
set -eu

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "ppc64le" ]]; then
    cross=true
elif [[ "$arch" == "s390x" ]]; then
    # binutils-x86-64-linux-gnu is not available on s390x
    echo "Skipping: binutils-x86-64-linux-gnu is not available on s390x"
    exit 0
elif [[ "$arch" == "x86_64" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    slices=(
        binutils-x86-64-linux-gnu_assembler
        binutils-x86-64-linux-gnu_cross-libbfd
        binutils-x86-64-linux-gnu_cross-libopcodes
    )

    rootfs_as="$(install-slices "${slices[@]}")"
    ln -s "x86_64-linux-gnu-as" "$rootfs_as/usr/bin/as"

    slices=(
        binutils-x86-64-linux-gnu_linker
        binutils-x86-64-linux-gnu_cross-libbfd
        binutils-x86-64-linux-gnu_cross-libctf
    )

    rootfs_ld="$(install-slices "${slices[@]}")"
    ln -s "x86_64-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
else
    rootfs_as="$(install-slices \
        binutils-x86-64-linux-gnu_assembler \
    )"
    ln -s "x86_64-linux-gnu-as" "$rootfs_as/usr/bin/as"

    # need libc6-dev_core for linking with libc
    rootfs_ld="$(install-slices \
        binutils-x86-64-linux-gnu_linker \
        libc6-dev_core \
    )"
    ln -s "x86_64-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
fi

cp "hello-x86_64-linux-gnu.S" "$rootfs_as/hello.S"
chroot "$rootfs_as" as hello.S -o hello.o
mv "$rootfs_as/hello.o" "$rootfs_ld/hello.o"

if $cross; then
    # TODO: This should compile but we don't have libc6-dev for cross compilation yet
    #       For now a cut-down version which is expected to fail due to no libc linking
    (chroot "$rootfs_ld" ld hello.o -o hello 2>&1 || true) | grep -q "cannot find entry symbol _start"
else
    linker_lib="$(ls "$rootfs_ld"/lib*/ld*.so*)"
    linker_lib=${linker_lib#"$rootfs_ld"}

    chroot "$rootfs_ld" ld hello.o -o hello \
        -dynamic-linker "${linker_lib}" \
        -lc \
        /usr/lib/x86_64-linux-gnu/crt1.o \
        /usr/lib/x86_64-linux-gnu/crti.o \
        /usr/lib/x86_64-linux-gnu/crtn.o

    chroot "$rootfs_ld" ./hello | grep "Hello world!" || exit 1
fi
