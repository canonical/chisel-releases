#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" cargo-1.84_cargo)"
ln -s gcc "$rootfs/usr/bin/cc"
ln -s rustc-1.84 "$rootfs/usr/bin/rustc"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_crate "$rootfs"

chroot "$rootfs" cargo-1.84 -Z unstable-options -C /hello_crate build --workspace
chroot "$rootfs" ./hello_crate/target/debug/hello | grep -q "Hello, world!"