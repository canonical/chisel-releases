#!/usr/bin/env bash
# spellchecker: ignore rootfs rustfmt

arch=$(uname -m)
case "${arch}" in
aarch64) chisel_arch="arm64" ;;
x86_64) chisel_arch="amd64" ;;
*)
  echo "Unsupported architecture: ${arch}"
  exit 1
  ;;
esac

# Test rustfmt reformats a badly formatted file
rootfs="$(install-slices --arch "$chisel_arch" rustfmt-1.93_rustfmt)"

cp testfiles/messy.rs "$rootfs/messy.rs"

# Before: no space before brace
grep -q 'fn main(){' "$rootfs/messy.rs"

chroot "$rootfs" /usr/lib/rust-1.93/bin/rustfmt /messy.rs

# After: proper formatting with space before brace
grep -q 'fn main() {' "$rootfs/messy.rs"

# Test cargo fmt reformats a project
rootfs="$(install-slices --arch "$chisel_arch" rustfmt-1.93_cargo-fmt cargo-1.93_cargo)"
ln -s /usr/lib/rust-1.93/bin/cargo-fmt "$rootfs/usr/bin/cargo-fmt"
ln -s /usr/lib/rust-1.93/bin/rustfmt "$rootfs/usr/bin/rustfmt"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_fmt "$rootfs"

# Before: no space before brace
grep -q 'fn main(){' "$rootfs/hello_fmt/src/main.rs"

chroot "$rootfs" cargo-1.93 -Z unstable-options -C /hello_fmt fmt

# After: proper formatting with space before brace
grep -q 'fn main() {' "$rootfs/hello_fmt/src/main.rs"
