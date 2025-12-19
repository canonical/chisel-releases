#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rustc-1.85)"
ln -s gcc "$rootfs/usr/bin/cc"

cp testfiles/hello.rs "$rootfs/hello.rs"

chroot "$rootfs" rustc-1.85 /hello.rs -o /hello
chroot "$rootfs" /hello | grep -q "Hello from Rust 1.85!"
