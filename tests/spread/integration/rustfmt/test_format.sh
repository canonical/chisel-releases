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
rootfs="$(install-slices --arch "$chisel_arch" rustfmt_rustfmt)"

cp testfiles/messy.rs "$rootfs/messy.rs"

# Before: no space before brace
grep -q 'fn main(){' "$rootfs/messy.rs"

chroot "$rootfs" rustfmt /messy.rs

# After: proper formatting with space before brace
grep -q 'fn main() {' "$rootfs/messy.rs"

# Test cargo fmt reformats a project
rootfs="$(install-slices --arch "$chisel_arch" rustfmt_cargo-fmt cargo_cargo)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_fmt "$rootfs"

# Before: no space before brace
grep -q 'fn main(){' "$rootfs/hello_fmt/src/main.rs"

chroot "$rootfs" cargo -Z unstable-options -C /hello_fmt fmt

# After: proper formatting with space before brace
grep -q 'fn main() {' "$rootfs/hello_fmt/src/main.rs"
