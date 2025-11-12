#!/usr/bin/env bash
# spellchecker: ignore rootfs libc libexec binutils unistd crti crtn

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

# prepare separate rootfs with cc1, as and ld
rootfs_cc="$(install-slices \
    base-files_bin \
    cpp-14-x86-64-linux-gnu_cc1 \
    libc6-dev_headers \
)"
rootfs_as="$(install-slices \
    binutils-x86-64-linux-gnu_assembler \
)"
rootfs_ld="$(install-slices \
    binutils-x86-64-linux-gnu_linker \
    libc6-dev_core \
)"

if $cross; then
    ln -s "/usr/libexec/gcc-cross/x86_64-linux-gnu/14/cc1" "${rootfs_cc}/usr/bin/cc1"
    ln -s "x86_64-linux-gnu-as" "${rootfs_as}/usr/bin/as"
    ln -s "x86_64-linux-gnu-ld" "${rootfs_ld}/usr/bin/ld"
else
    ln -s "/usr/libexec/gcc/x86_64-linux-gnu/14/cc1" "${rootfs_cc}/usr/bin/cc1"
    ln -s "x86_64-linux-gnu-as" "${rootfs_as}/usr/bin/as"
    ln -s "x86_64-linux-gnu-ld" "${rootfs_ld}/usr/bin/ld"
fi

# NOTE: is this the correct linker path for cross compilation too?
dynamic_linker="$(find "${rootfs_ld}" -type f -name "ld-linux-*.so.*" -printf "%P\n" -quit)"

cp hello.c "${rootfs_cc}/hello.c"

if $cross; then
    # TODO: We do not have libc6-dev for cross compilation yet
    :
else
    # compile
    chroot "${rootfs_cc}" cc1 hello.c \
        -o hello.s \
        -Wno-implicit-function-declaration \
        -I "/usr/include/$arch-linux-gnu" \
        -I "/usr/include/linux"

    # assemble
    cp "${rootfs_cc}/hello.s" "${rootfs_as}/hello.s"
    chroot "${rootfs_as}" as -o hello.o hello.s

    # link
    cp "${rootfs_as}/hello.o" "${rootfs_ld}/hello.o"
    chroot "${rootfs_ld}" ld -o hello hello.o \
        -dynamic-linker "$dynamic_linker" \
        -lc \
        /usr/lib/"$arch"-linux-gnu/crt1.o \
        /usr/lib/"$arch"-linux-gnu/crti.o \
        /usr/lib/"$arch"-linux-gnu/crtn.o

    # run
    chroot "${rootfs_ld}" /hello | grep -q "Hello, world!"
fi
