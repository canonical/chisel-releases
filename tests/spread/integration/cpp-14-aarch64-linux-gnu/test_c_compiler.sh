#!/usr/bin/env bash
# spellchecker: ignore rootfs libc libexec binutils unistd crti crtn

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

# prepare separate rootfs with cc1, as and ld
if $cross; then
    rootfs_cc="$(install-slices \
        base-files_bin \
        cpp-14-aarch64-linux-gnu_cc1 \
        libc6-dev_headers \
    )"
    ln -s "/usr/libexec/gcc-cross/aarch64-linux-gnu/14/cc1" "${rootfs_cc}/usr/bin/cc1"

    rootfs_as="$(install-slices \
        binutils-aarch64-linux-gnu_assembler \
    )"
    ln -s "aarch64-linux-gnu-as" "${rootfs_as}/usr/bin/as"

    rootfs_ld="$(install-slices \
        binutils-aarch64-linux-gnu_linker \
        libc6-dev_core \
    )"
    ln -s "aarch64-linux-gnu-ld" "${rootfs_ld}/usr/bin/ld"
else
    rootfs_cc="$(install-slices \
        base-files_bin \
        cpp-14-aarch64-linux-gnu_cc1 \
        libc6-dev_headers \
    )"
    ln -s "/usr/libexec/gcc/aarch64-linux-gnu/14/cc1" "${rootfs_cc}/usr/bin/cc1"

    rootfs_as="$(install-slices \
        binutils-aarch64-linux-gnu_assembler \
    )"
    ln -s "aarch64-linux-gnu-as" "${rootfs_as}/usr/bin/as"

    rootfs_ld="$(install-slices \
        binutils-aarch64-linux-gnu_linker \
        libc6-dev_core \
    )"
    ln -s "aarch64-linux-gnu-ld" "${rootfs_ld}/usr/bin/ld"

fi

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
        -dynamic-linker "$(find "${rootfs_ld}" -type f -name "ld-linux-*.so.*" -printf "%P\n" -quit)" \
        -lc \
        /usr/lib/"$arch"/crt1.o \
        /usr/lib/"$arch"/crti.o \
        /usr/lib/"$arch"/crtn.o

    # run
    chroot "${rootfs_ld}" /hello | grep -q "Hello, world!"
fi