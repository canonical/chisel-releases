#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" cargo-1.85_cargo)"
ln -s gcc "$rootfs/usr/bin/cc"
ln -s rustc-1.85_rustc "$rootfs/usr/bin/rustc"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# Use cargo to create, build and run a simple "Hello, world!" program
# (cargo new already creates a hello world program by default)
chroot "$rootfs" cargo-1.85 new hello --bin

chroot "$rootfs" cargo-1.85 -Z unstable-options -C hello build
chroot "$rootfs" ./hello/target/debug/hello | grep -q "Hello, world!"

# Now in release mode
chroot "$rootfs" cargo-1.85 -Z unstable-options -C hello build --release
chroot "$rootfs" ./hello/target/release/hello | grep -q "Hello, world!"