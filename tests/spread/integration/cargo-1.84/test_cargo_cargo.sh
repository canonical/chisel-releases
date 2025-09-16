#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs rustc binutils libgcc archiver resolv libopenssl

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

version_string=$(chroot "${rootfs}" cargo --version)
# cargo 1.84.1 (66221abde 2024-11-19)
sha=${version_string#* (}
sha=${sha%% *}
url="https://github.com/rust-lang/cargo.git"

git clone "$url" "${rootfs}"/cargo -b "master" --single-branch
git -C "${rootfs}"/cargo reset --hard "$sha"

# at the moment the full build fails because it needs libopenssl-dev
# which we don't have a slice for
# so we just build the build plan to verify that cargo itself works
chroot "${rootfs}" cargo \
    -Z unstable-options \
    -C /cargo \
    build \
    -j1 \
    --build-plan > "${rootfs}/build-plan.json"
cat "${rootfs}/build-plan.json" | jq -r '.invocations[].package_name' | grep -q "^cargo$"
