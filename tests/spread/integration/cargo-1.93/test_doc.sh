#!/usr/bin/env bash
# spellchecker: ignore rootfs cargo

rootfs="$(install-slices cargo-1.93_cargo rustc-1.93_rustdoc)"
ln -s cargo-1.93 "$rootfs/usr/bin/cargo"

# Create minimal /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_crate "$rootfs"

chroot "$rootfs" cargo doc --manifest-path /hello_crate/Cargo.toml
test -f "$rootfs/hello_crate/target/doc/hello/index.html"
test -f "$rootfs/hello_crate/target/doc/greeter/index.html"
