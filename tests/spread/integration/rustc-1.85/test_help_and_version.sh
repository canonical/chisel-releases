#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rustc-1.84_rustc)"
# ln -s gcc "$rootfs/usr/bin/cc"  # not needed for help/version

chroot "${rootfs}/" rustc-1.84 --help | grep -q "Usage: rustc"
chroot "${rootfs}/" rustc-1.84 --version | grep -q 'rustc 1.84'
