#!/usr/bin/env bash
# spellchecker: ignore rootfs

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" cargo-1.93_cargo)"
# ln -s rustc-1.93 "$rootfs/usr/bin/rustc"  # not needed for help/version

chroot "$rootfs" cargo-1.93 --help | grep -q "Rust's package manager"
chroot "$rootfs" cargo-1.93 --version | grep -q 'cargo 1.93'