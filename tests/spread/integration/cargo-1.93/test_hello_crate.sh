#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices cargo-1.93_cargo)"
ln -s rustc-1.93 "$rootfs/usr/bin/rustc"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_crate "$rootfs"

chroot "$rootfs" cargo-1.93 -Z unstable-options -C /hello_crate build --workspace
chroot "$rootfs" ./hello_crate/target/debug/hello | grep -q "Hello, world!"