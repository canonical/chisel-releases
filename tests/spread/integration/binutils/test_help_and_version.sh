#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils

arch=$(uname -m)-linux-gnu
arch="${arch//_/-}"

rootfs="$(install-slices \
    binutils_assembler \
    binutils-"${arch}"_assembler \
    binutils_linker \
    binutils-"${arch}"_linker \
)"

chroot "${rootfs}" as --help | grep -q "Usage: as"
# NOTE: ld --help blows up in pipefail mode when piped...
(chroot "${rootfs}" ld --help || true) | grep -q "Usage: ld"

chroot "${rootfs}" as --version | grep -q "GNU assembler"
chroot "${rootfs}" ld --version | grep -q "GNU ld"