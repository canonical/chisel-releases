#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rustc-1.88_rustc)"
ln -s gcc "$rootfs/usr/bin/cc"


cp testfiles/test_std.rs "${rootfs}"/test_std.rs

chroot "${rootfs}" rustc-1.88 /test_std.rs -o /test_std
chroot "${rootfs}" /test_std
