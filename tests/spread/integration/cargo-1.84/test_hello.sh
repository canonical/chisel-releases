#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs rustc binutils libgcc

arch=$(uname -m)-linux-gnu
slices=(
    cargo-1.84_cargo
    rustc-1.84_rustc
    gcc-14-"${arch//_/-}"_gcc-14
    binutils-"${arch//_/-}"_linker
    libgcc-14-dev_libgcc
)
rootfs="$(install-slices "${slices[@]}")"
ln -s rustc-1.84 "${rootfs}"/usr/bin/rustc
ln -s cargo-1.84 "${rootfs}"/usr/bin/cargo
ln -s "${arch}"-gcc-14 "${rootfs}"/usr/bin/cc
ln -s "${arch}"-ld "${rootfs}"/usr/bin/ld

# Create minimal /dev/null 
mkdir -p "${rootfs}"/dev
touch "${rootfs}"/dev/null
chmod +x "${rootfs}"/dev/null

# Use cargo to create, build and run a simple "Hello, world!" program
# (cargo new already creates a hello world program by default)
chroot "${rootfs}" cargo new hello --bin

chroot "${rootfs}" cargo -Z unstable-options -C hello build
chroot "${rootfs}" ./hello/target/debug/hello | grep -q "Hello, world!"

# Now in release mode
chroot "${rootfs}" cargo -Z unstable-options -C hello build --release
chroot "${rootfs}" ./hello/target/release/hello | grep -q "Hello, world!"
