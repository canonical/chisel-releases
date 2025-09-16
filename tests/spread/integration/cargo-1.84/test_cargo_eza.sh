#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs rustc binutils libgcc archiver resolv

arch=$(uname -m)-linux-gnu
slices=(
    cargo-1.84_cargo
    rustc-1.84_rustc
    gcc-14-"${arch//_/-}"_gcc-14
    binutils-"${arch//_/-}"_linker
    libgcc-14-dev_libgcc
)
# we need cpp and as for gcc to be able to create executables
slices+=(
    cpp-14-"${arch//_/-}"_cc1
    binutils-"${arch//_/-}"_assembler
)
# the zlib dependency requires ar
slices+=(
    binutils-"${arch//_/-}"_archiver
)
slices+=(
    ca-certificates_data
)
rootfs="$(install-slices "${slices[@]}")"
ln -s rustc-1.84 "${rootfs}"/usr/bin/rustc
ln -s cargo-1.84 "${rootfs}"/usr/bin/cargo
ln -s "${arch}"-gcc-14 "${rootfs}"/usr/bin/cc
ln -s "${arch}"-ld "${rootfs}"/usr/bin/ld
ln -s "${arch}"-as "${rootfs}"/usr/bin/as
ln -s "${arch}"-ar "${rootfs}"/usr/bin/ar

# Create minimal /dev/null 
mkdir -p "${rootfs}"/dev
touch "${rootfs}"/dev/null
chmod +x "${rootfs}"/dev/null

# We need DNS to fetch crates.io dependencies
mkdir -p "${rootfs}"/etc
cp /etc/resolv.conf "${rootfs}"/etc/resolv.conf

url="https://github.com/eza-community/eza.git"
tag="v0.23.3"
git clone "$url" "${rootfs}"/eza -b "$tag" --single-branch

chroot "${rootfs}" cargo -Z unstable-options -C /eza build

# Run the built eza binary to verify it works
chroot "${rootfs}" /eza/target/debug/eza --help | grep -q "eza \[options\] \[files...\]"
touch "${rootfs}"/tmp/testfile
chroot "${rootfs}" /eza/target/debug/eza /tmp | grep -q "testfile"
