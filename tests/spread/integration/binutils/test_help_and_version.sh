#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils

arch=$(uname -m)-linux-gnu

rootfs="$(install-slices \
    binutils-"${arch//_/-}"_assembler \
    binutils-"${arch//_/-}"_linker \
)"
ln -s "${arch}-as" "${rootfs}/usr/bin/as"
ln -s "${arch}-ld" "${rootfs}/usr/bin/ld"

chroot "${rootfs}" as --help | grep -q "Usage: as"
# NOTE: ld --help blows up in pipefail mode when piped...
(chroot "${rootfs}" ld --help || true) | grep -q "Usage: ld"

chroot "${rootfs}" as --version | grep -q "GNU assembler"
chroot "${rootfs}" ld --version | grep -q "GNU ld"