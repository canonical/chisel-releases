#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs libc libexec binutils unistd crti crtn
arch=$(uname -m)-linux-gnu

# prepare separate rootfs with cc1, as and ld
rootfs_cc="$(install-slices \
    base-files_bin \
    cpp-14-"${arch//_/-}"_cc1 \
    libc6-dev_headers \
)"
ln -s "/usr/libexec/gcc/$arch/14/cc1" "${rootfs_cc}/usr/bin/cc1"

rootfs_as="$(install-slices \
    binutils-"${arch//_/-}"_assembler \
)"
ln -s "${arch}-as" "${rootfs_as}/usr/bin/as"

rootfs_ld="$(install-slices \
    binutils-"${arch//_/-}"_linker \
    libc6-dev_posix-libs \
)"
ln -s "${arch}-ld" "${rootfs_ld}/usr/bin/ld"

# hello world
cat > "${rootfs_cc}/hello.c"<<EOF
#include <unistd.h>
int main() {
    const char msg[] = "Hello, world!\n";
    write(1, msg, sizeof(msg) - 1);
    return 0;
}
EOF

# compile
chroot "${rootfs_cc}" cc1 hello.c \
    -o hello.s \
    -Wno-implicit-function-declaration \
    -I "/usr/include/$arch" \
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
