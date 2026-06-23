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

rootfs="$(install-slices --arch "$chisel_arch" rust-1.93-src_src)"

# The versioned package provides two symlinks to the source tree:
#   /usr/lib/rust-1.93/lib/rustlib/src/rust -> ../../../../../src/rustc-1.93.1
#   /usr/lib/rust-1.93/rustlib/src/rust     -> ../../../../src/rustc-1.93.1
test -L "$rootfs/usr/lib/rust-1.93/lib/rustlib/src/rust"
test -L "$rootfs/usr/lib/rust-1.93/rustlib/src/rust"

# Verify both symlinks resolve to the source tree
test -f "$rootfs/usr/lib/rust-1.93/lib/rustlib/src/rust/library/std/src/lib.rs"
test -f "$rootfs/usr/lib/rust-1.93/lib/rustlib/src/rust/compiler/rustc/Cargo.toml"
test -f "$rootfs/usr/lib/rust-1.93/rustlib/src/rust/library/std/src/lib.rs"
test -f "$rootfs/usr/lib/rust-1.93/rustlib/src/rust/compiler/rustc/Cargo.toml"

# Verify the actual source tree exists
test -f "$rootfs/usr/src/rustc-1.93.1/library/std/src/lib.rs"
test -f "$rootfs/usr/src/rustc-1.93.1/compiler/rustc/Cargo.toml"
test -f "$rootfs/usr/src/rustc-1.93.1/Cargo.toml"
