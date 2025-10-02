#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils libc crti crtn

arch=$(uname -m)-linux-gnu

rootfs_as="$(install-slices \
    binutils-"${arch//_/-}"_assembler \
)"
ln -s "$arch-as" "$rootfs_as/usr/bin/as"

cp hello-"$arch".S "$rootfs_as/hello.S"
chroot "$rootfs_as" as hello.S -o hello.o

# need libc6-dev_core for linking with libc
rootfs_ld="$(install-slices \
    binutils-"${arch//_/-}"_linker \
    libc6-dev_core \
)"
ln -s "$arch-ld" "$rootfs_ld/usr/bin/ld"

mv "$rootfs_as/hello.o" "$rootfs_ld/hello.o"

linker_lib="$(ls "$rootfs_ld"/usr/lib*/ld-*.so*)"
linker_lib=${linker_lib#"$rootfs_ld"}

chroot "$rootfs_ld" ld hello.o -o hello \
    -dynamic-linker "${linker_lib}" \
    -lc \
    /usr/lib/"$arch"/crt1.o \
    /usr/lib/"$arch"/crti.o \
    /usr/lib/"$arch"/crtn.o
chroot "$rootfs_ld" ./hello | grep "Hello world!" || exit 1
