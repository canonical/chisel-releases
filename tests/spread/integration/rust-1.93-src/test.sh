#!/usr/bin/env bash
# spellchecker: ignore rootfs rustlib

rootfs="$(install-slices rust-1.93-src_src)"

# The versioned package provides two symlinks to the source tree:
#   /usr/lib/rust-1.93/lib/rustlib/src/rust -> ../../../../../src/rustc-1.93.*
#   /usr/lib/rust-1.93/rustlib/src/rust     -> ../../../../src/rustc-1.93.*
test -L "$rootfs/usr/lib/rust-1.93/lib/rustlib/src/rust"
test -L "$rootfs/usr/lib/rust-1.93/rustlib/src/rust"

# Verify both symlinks resolve to the source tree
test -f "$rootfs/usr/lib/rust-1.93/lib/rustlib/src/rust/library/std/src/lib.rs"
test -f "$rootfs/usr/lib/rust-1.93/lib/rustlib/src/rust/compiler/rustc/Cargo.toml"
test -f "$rootfs/usr/lib/rust-1.93/rustlib/src/rust/library/std/src/lib.rs"
test -f "$rootfs/usr/lib/rust-1.93/rustlib/src/rust/compiler/rustc/Cargo.toml"

# Verify the actual source tree exists (don't pin the patch version)
shopt -s nullglob  # no match -> empty array, not the literal glob
src_dirs=("$rootfs"/usr/src/rustc-1.93.*)
test "${#src_dirs[@]}" -eq 1   # exactly one source tree
src_dir="${src_dirs[0]}"
shopt -u nullglob
test -d "$src_dir"
test -f "$src_dir/library/std/src/lib.rs"
test -f "$src_dir/compiler/rustc/Cargo.toml"
test -f "$src_dir/Cargo.toml"
