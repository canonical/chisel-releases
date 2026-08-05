#!/usr/bin/env bash
# spellchecker: ignore rootfs libc libexec binutils unistd crti crtn
set -eu

# prepare separate rootfs with cc1, as and ld
rootfs_cc="$(install-slices \
    base-files_bin \
    cpp-11_cc1 \
)"
rootfs_as="$(install-slices \
    binutils_assembler \
)"
rootfs_ld="$(install-slices \
    binutils_linker \
    libc6-dev_core \
)"

triplet="$(cd "${rootfs_cc}/usr/lib/gcc" && echo *)"

ln -s "/usr/lib/gcc/${triplet}/11/cc1" "${rootfs_cc}/usr/bin/cc1"

dynamic_linker="$(ls "${rootfs_ld}"/lib*/ld*.so*)"
dynamic_linker=${dynamic_linker#"$rootfs_ld"}

cp hello.c "${rootfs_cc}/hello.c"

# compile
chroot "${rootfs_cc}" cc1 hello.c \
    -o hello.s \
    -Wno-implicit-function-declaration \
    -I "/usr/include/${triplet}" \
    -I "/usr/include/linux"

# assemble
cp "${rootfs_cc}/hello.s" "${rootfs_as}/hello.s"
chroot "${rootfs_as}" as -o hello.o hello.s

# link
cp "${rootfs_as}/hello.o" "${rootfs_ld}/hello.o"
chroot "${rootfs_ld}" ld -o hello hello.o \
    -dynamic-linker "${dynamic_linker}" \
    -lc \
    /usr/lib/${triplet}/crt1.o \
    /usr/lib/${triplet}/crti.o \
    /usr/lib/${triplet}/crtn.o

# run
chroot "${rootfs_ld}" /hello | grep -q "Hello, world!"
