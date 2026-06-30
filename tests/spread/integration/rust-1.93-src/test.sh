#!/usr/bin/env bash
# spellchecker: ignore rootfs rustlib

rootfs="$(install-slices rust-1.93-src_src)"

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
