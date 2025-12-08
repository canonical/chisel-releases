#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc binutils libgcc

arch=$(uname -m)-linux-gnu
slices=(
    rustc-1.84_rustc
    gcc-14-"${arch//_/-}"_gcc-14
    binutils-"${arch//_/-}"_linker
    libgcc-14-dev_core
)
rootfs="$(install-slices "${slices[@]}")"
ln -s "${arch}"-gcc-14 "${rootfs}"/usr/bin/cc
ln -s "${arch}"-ld "${rootfs}"/usr/bin/ld

cp testfiles/test_std.rs "${rootfs}"/test_std.rs

chroot "${rootfs}" rustc-1.84 /test_std.rs -o /test_std
chroot "${rootfs}" /test_std
