#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libc crti crtn libbfd libctf libopcodes

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
    slices=(
        binutils-aarch64-linux-gnu_assembler
        binutils-aarch64-linux-gnu_cross-libbfd
    )
    # when compiling from x86_64 to aarch64 we also need libopcodes
    slices+=(binutils-aarch64-linux-gnu_cross-libopcodes)

    rootfs_as="$(install-slices "${slices[@]}")"
    ln -s "aarch64-linux-gnu-as" "$rootfs_as/usr/bin/as"

    slices=(
        binutils-aarch64-linux-gnu_linker
        binutils-aarch64-linux-gnu_cross-libbfd
        binutils-aarch64-linux-gnu_cross-libctf
    )
    # when compiling from x86_64 to aarch64 we also need libopcodes
    slices+=(binutils-aarch64-linux-gnu_cross-libopcodes)
    
    rootfs_ld="$(install-slices "${slices[@]}")"
    ln -s "aarch64-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
else
    rootfs_as="$(install-slices \
        binutils-aarch64-linux-gnu_assembler \
    )"
    ln -s "aarch64-linux-gnu-as" "$rootfs_as/usr/bin/as"

    # need libc6-dev_core for linking with libc
    rootfs_ld="$(install-slices \
        binutils-aarch64-linux-gnu_linker \
        libc6-dev_core \
    )"
    ln -s "aarch64-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
fi

cp "hello-aarch64-linux-gnu.S" "$rootfs_as/hello.S"
chroot "$rootfs_as" as hello.S -o hello.o
mv "$rootfs_as/hello.o" "$rootfs_ld/hello.o"

linker_lib="$(ls "$rootfs_ld"/usr/lib*/ld-*.so*)"
linker_lib=${linker_lib#"$rootfs_ld"}

if $cross; then
    # TODO: This should compile but we don't have libc6-dev for cross compilation yet
    #       For now a cut-down version which is expected to fail due to no libc linking
    # chroot "$rootfs_ld" ld hello.o -o hello \
    #     -dynamic-linker "${linker_lib}" \
    #     -lc \
    #     /usr/lib/"$other"/crt1.o \
    #     /usr/lib/"$other"/crti.o \
    #     /usr/lib/"$other"/crtn.o
    (chroot "$rootfs_ld" ld hello.o -o hello \
        -dynamic-linker "$linker_lib" 2>&1 || true) | grep -q "cannot find entry symbol _start"
else
    chroot "$rootfs_ld" ld hello.o -o hello \
        -dynamic-linker "${linker_lib}" \
        -lc \
        /usr/lib/aarch64-linux-gnu/crt1.o \
        /usr/lib/aarch64-linux-gnu/crti.o \
        /usr/lib/aarch64-linux-gnu/crtn.o
    chroot "$rootfs_ld" ./hello | grep "Hello world!" || exit 1
fi
