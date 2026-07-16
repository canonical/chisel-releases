#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libc crti crtn libbfd libctf libopcodes

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "x86_64" ]]; then
    cross=true
elif [[ "$arch" == "s390x" ]]; then
    # binutils-powerpc64le-linux-gnu is not available on s390x
    echo "Skipping: binutils-powerpc64le-linux-gnu is not available on s390x"
    exit 0
elif [[ "$arch" == "ppc64le" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    slices=(
        binutils-powerpc64le-linux-gnu_assembler
        binutils-powerpc64le-linux-gnu_cross-libbfd
        binutils-powerpc64le-linux-gnu_cross-libopcodes
    )

    rootfs_as="$(install-slices "${slices[@]}")"
    ln -s "powerpc64le-linux-gnu-as" "$rootfs_as/usr/bin/as"

    slices=(
        binutils-powerpc64le-linux-gnu_linker
        binutils-powerpc64le-linux-gnu_cross-libbfd
        binutils-powerpc64le-linux-gnu_cross-libctf
    )

    rootfs_ld="$(install-slices "${slices[@]}")"
    ln -s "powerpc64le-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
else
    rootfs_as="$(install-slices \
        binutils-powerpc64le-linux-gnu_assembler \
    )"
    ln -s "powerpc64le-linux-gnu-as" "$rootfs_as/usr/bin/as"

    # need libc6-dev_core for linking with libc
    rootfs_ld="$(install-slices \
        binutils-powerpc64le-linux-gnu_linker \
        libc6-dev_core \
    )"
    ln -s "powerpc64le-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
fi

cp "hello-ppc64le-linux-gnu.S" "$rootfs_as/hello.S"
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
        /usr/lib/powerpc64le-linux-gnu/crt1.o \
        /usr/lib/powerpc64le-linux-gnu/crti.o \
        /usr/lib/powerpc64le-linux-gnu/crtn.o

    chroot "$rootfs_ld" ./hello | grep "Hello world!" || exit 1
fi
