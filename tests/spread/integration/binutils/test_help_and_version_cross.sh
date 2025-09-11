#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils libbfd libctf

this=$(uname -m)
if [[ "$this" == "x86_64" ]]; then
    other="aarch64"
elif [[ "$this" == "aarch64" ]]; then
    other="x86_64"
else
    echo "Unsupported architecture: $this"
    exit 1
fi

this="$this"-linux-gnu
other="$other"-linux-gnu

rootfs_as="$(install-slices \
    binutils-"${other//_/-}"_assembler \
    binutils-"${other//_/-}"_cross-libbfd \
)"
ln -s "${other}-as" "${rootfs_as}/usr/bin/as"

chroot "${rootfs_as}" as --help | grep -q "Usage: as"
chroot "${rootfs_as}" as --version | grep -q "GNU assembler"

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

# # NOTE: ld --help blows up in pipefail mode when piped...
(chroot "${rootfs_ld}" ld --help || true) | grep -q "Usage: ld"
chroot "${rootfs_ld}" ld --version | grep -q "GNU ld"