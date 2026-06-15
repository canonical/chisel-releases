#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc clippy

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rust-1.93-clippy_clippy cargo-1.93_cargo)"
ln -s rustc-1.93 "$rootfs/usr/bin/rustc"

# Create minimal /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_clippy "$rootfs"

# Verify clippy runs and reports the expected lint warning
chroot "$rootfs" cargo-1.93 -Z unstable-options -C /hello_clippy clippy 2>&1 \
    | grep -q "clippy::len_zero"
