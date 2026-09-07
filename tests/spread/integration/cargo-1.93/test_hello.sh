#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

rootfs="$(install-slices cargo-1.93_cargo)"
ln -s rustc-1.93 "$rootfs/usr/bin/rustc"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# Use cargo to create, build and run a simple "Hello, world!" program
# (cargo new already creates a hello world program by default)
chroot "$rootfs" cargo-1.93 new hello --bin

chroot "$rootfs" cargo-1.93 -Z unstable-options -C hello build
chroot "$rootfs" ./hello/target/debug/hello | grep -q "Hello, world!"

# Now in release mode
chroot "$rootfs" cargo-1.93 -Z unstable-options -C hello build --release
chroot "$rootfs" ./hello/target/release/hello | grep -q "Hello, world!"