#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils crti crtn

arch=$(uname -m)-linux-gnu
arch="${arch//_/-}"

rootfs_as="$(install-slices \
    binutils_assembler \
    binutils-"${arch}"_assembler \
)"

cp hello-"${arch}".S "${rootfs_as}/hello.S"
chroot "${rootfs_as}" as hello.S -o hello.o

rootfs_ld="$(install-slices \
    binutils_linker \
    binutils-"${arch}"_linker \
)"

mv "${rootfs_as}/hello.o" "${rootfs_ld}/hello.o"

linker_lib="$(ls "${rootfs_ld}"/usr/lib*/ld-*.so*)"
linker_lib=${linker_lib#"${rootfs_ld}"}

chroot "${rootfs_ld}" ld hello.o -o hello \
    -dynamic-linker "${linker_lib}" \
    -lc \
    /usr/lib/"$arch"/crt1.o \
    /usr/lib/"$arch"/crti.o \
    /usr/lib/"$arch"/crtn.o
chroot "${rootfs_ld}" ./hello | grep "Hello world!" || exit 1
