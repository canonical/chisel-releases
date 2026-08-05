#!/usr/bin/env bash
# spellchecker: ignore rootfs libc libexec binutils unistd crti crtn
set -eu

arch=$(uname -m)
case "$arch" in
    x86_64)   triplet="x86_64-linux-gnu" ;;
    aarch64)  triplet="aarch64-linux-gnu" ;;
    ppc64le)  triplet="powerpc64le-linux-gnu" ;;
    s390x)    triplet="s390x-linux-gnu" ;;
    *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
esac

# prepare separate rootfs with cc1, as and ld
rootfs_cc="$(install-slices \
    base-files_bin \
    cpp-11_cc1 \
    libc6-dev_headers \
)"
rootfs_as="$(install-slices \
    binutils_assembler \
)"
rootfs_ld="$(install-slices \
    binutils_linker \
    libc6-dev_core \
)"

ln -s "/usr/lib/gcc/${triplet}/11/cc1" "${rootfs_cc}/usr/bin/cc1"

dynamic_linker="$(find "${rootfs_ld}" -type f -name "ld*.so.*" -printf "%P\n" -quit)"

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
    -dynamic-linker "/${dynamic_linker}" \
    -lc \
    /usr/lib/${triplet}/crt1.o \
    /usr/lib/${triplet}/crti.o \
    /usr/lib/${triplet}/crtn.o

# run
chroot "${rootfs_ld}" /hello | grep -q "Hello, world!"
