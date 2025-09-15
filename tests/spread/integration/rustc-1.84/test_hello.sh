#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs rustc binutils libgcc println

rootfs="$(install-slices rustc-1.84_rustc)"
arch=$(uname -m)-linux-gnu
slices=(
    rustc-1.84_rustc
    gcc-14-"${arch//_/-}"_gcc-14
    binutils-"${arch//_/-}"_linker
    libgcc-14-dev_libgcc
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${arch}"-gcc-14 "${rootfs}"/usr/bin/cc
ln -s "${arch}"-ld "${rootfs}"/usr/bin/ld

echo 'fn main() { println!("Hello from Rust!"); }' > "${rootfs}"/hello.rs
chroot "${rootfs}" rustc-1.84 /hello.rs -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from Rust!"