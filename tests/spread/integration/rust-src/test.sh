#!/usr/bin/env bash
# spellchecker: ignore rootfs rustlib

arch=$(uname -m)
case "${arch}" in
aarch64) chisel_arch="arm64" ;;
x86_64) chisel_arch="amd64" ;;
*)
  echo "Unsupported architecture: ${arch}"
  exit 1
  ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rust-src_src)"

# The unversioned symlink chain should resolve to the source tree
# /usr/lib/rustlib/src/rust -> ../../rust-1.93/lib/rustlib/src/rust -> /usr/src/rustc-1.93.1
test -L "$rootfs/usr/lib/rustlib/src/rust"
test -f "$rootfs/usr/lib/rustlib/src/rust/library/std/src/lib.rs"
test -f "$rootfs/usr/lib/rustlib/src/rust/library/core/src/lib.rs"
test -f "$rootfs/usr/lib/rustlib/src/rust/library/alloc/src/lib.rs"
test -f "$rootfs/usr/lib/rustlib/src/rust/compiler/rustc/Cargo.toml"
test -f "$rootfs/usr/lib/rustlib/src/rust/src/bootstrap/Cargo.toml"
test -f "$rootfs/usr/lib/rustlib/src/rust/Cargo.toml"
test -f "$rootfs/usr/lib/rustlib/src/rust/README.md"

# Verify the actual source tree exists
test -f "$rootfs/usr/src/rustc-1.93.1/library/std/src/lib.rs"
test -f "$rootfs/usr/src/rustc-1.93.1/compiler/rustc/Cargo.toml"
test -f "$rootfs/usr/src/rustc-1.93.1/Cargo.toml"
