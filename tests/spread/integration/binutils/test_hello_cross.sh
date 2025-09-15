#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils libbfd libopcodes libctf
# spellchecker: ignore libc crti crtn

this=$(uname -m)
if [[ "$this" == "x86_64" ]]; then
    other="aarch64"
elif [[ "$this" == "aarch64" ]]; then
    other="x86_64"
else
    echo "Unsupported architecture: $this"
    exit 1
fi

echo "Testing cross-compilation from $this to $other"

this="$this"-linux-gnu
other="$other"-linux-gnu

slices=(
    binutils-"${other//_/-}"_assembler
    binutils-"${other//_/-}"_cross-libbfd
)
if [[ "$this" == "x86_64-linux-gnu" ]]; then
    # when compiling from x86_64 to aarch64 we also need libopcodes
    slices+=(binutils-"${other//_/-}"_cross-libopcodes)
fi
rootfs_as="$(install-slices "${slices[@]}")"
ln -s "${other}-as" "${rootfs_as}/usr/bin/as"

cp hello-"${other}".S "${rootfs_as}/hello.S"
chroot "${rootfs_as}" as hello.S -o hello.o


slices=(
    binutils-"${other//_/-}"_linker
    binutils-"${other//_/-}"_cross-libbfd
    binutils-"${other//_/-}"_cross-libctf
)
if [[ "$this" == "x86_64-linux-gnu" ]]; then
    # when compiling from x86_64 to aarch64 we also need libopcodes
    slices+=(binutils-"${other//_/-}"_cross-libopcodes)
fi
rootfs_ld="$(install-slices "${slices[@]}")"
ln -s "${other}-ld" "${rootfs_ld}/usr/bin/ld"

mv "${rootfs_as}/hello.o" "${rootfs_ld}/hello.o"

linker_lib="$(ls "${rootfs_ld}"/usr/lib*/ld-*.so*)"
linker_lib=${linker_lib#"${rootfs_ld}"}


# TODO: This should compile but we don't have libc6-dev for cross compilation yet
#       For now a cut-down version which is expected to fail due to no libc linking
# chroot "${rootfs_ld}" ld hello.o -o hello \
#     -dynamic-linker "${linker_lib}" \
#     -lc \
#     /usr/lib/"$other"/crt1.o \
#     /usr/lib/"$other"/crti.o \
#     /usr/lib/"$other"/crtn.o


(chroot "${rootfs_ld}" ld hello.o -o hello \
    -dynamic-linker "${linker_lib}" 2>&1 || true) | grep -q "cannot find entry symbol _start"
