#!/usr/bin/env bash
# spellchecker: ignore rootfs rustfmt

source ./shared.sh
# Test rustfmt reformats a badly formatted file
rootfs="$(install-slices rustfmt-1.97_rustfmt)"

cp testfiles/messy.rs "$rootfs/messy.rs"

# Before: no space before brace
grep -Fq 'fn main(){' "$rootfs/messy.rs"

chroot "$rootfs" /usr/lib/rust-1.97/bin/rustfmt /messy.rs

# After: proper formatting with space before brace
grep -Fq 'fn main() {' "$rootfs/messy.rs"

# Test cargo fmt reformats a project
rootfs="$(install-slices rustfmt-1.97_cargo-fmt cargo-1.97_cargo)"
mount_proc
ln -s /usr/lib/rust-1.97/bin/cargo-fmt "$rootfs/usr/bin/cargo-fmt"
ln -s /usr/lib/rust-1.97/bin/rustfmt "$rootfs/usr/bin/rustfmt"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_fmt "$rootfs"

# Before: no space before brace
grep -Fq 'fn main(){' "$rootfs/hello_fmt/src/main.rs"

chroot "$rootfs" cargo-1.97 -Z unstable-options -C /hello_fmt fmt

# After: proper formatting with space before brace
grep -Fq 'fn main() {' "$rootfs/hello_fmt/src/main.rs"
