#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs rustc libgcc

rootfs="$(install-slices rustc-1.84_rustc)"
arch=$(uname -m)-linux-gnu
slices=(
    rustc-1.84_rustc
    libgcc-14-dev_libs
    gcc-14-"$(echo "$arch" | sed 's/_/-/')"_rustc-184-minimal
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${arch}"-gcc-14 "${rootfs}"/usr/bin/cc
ln -s "${arch}"-ld "${rootfs}"/usr/bin/ld

echo 'fn main() { println!("Hello from Rust!"); }' > ${rootfs}/hello.rs
chroot "${rootfs}" rustc-1.84 /hello.rs -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from Rust!"