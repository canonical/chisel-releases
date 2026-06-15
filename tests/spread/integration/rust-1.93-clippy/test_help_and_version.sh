#!/usr/bin/env bash
# spellchecker: ignore rootfs clippy

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rust-1.93-clippy_clippy)"

chroot "$rootfs" /usr/lib/rust-1.93/bin/clippy-driver --version | grep -q 'clippy 1.93'
