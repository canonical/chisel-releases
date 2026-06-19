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

# test rustfmt slice
rootfs="$(install-slices --arch "$chisel_arch" rustfmt_rustfmt)"
chroot "$rootfs" rustfmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" rustfmt --help | grep -q 'Format Rust code'
chroot "$rootfs" rustfmt --help | grep -q 'usage: rustfmt'

# test cargo-fmt slice
rootfs="$(install-slices --arch "$chisel_arch" rustfmt_cargo-fmt)"
# installing cargo-fmt also makes rustfmt available
chroot "$rootfs" cargo-fmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" cargo-fmt --help | grep -q 'This utility formats all bin and lib files of the current crate using rustfmt'
chroot "$rootfs" cargo-fmt --help | grep -q 'Usage: cargo fmt'

# test with `cargo fmt`
rootfs="$(install-slices --arch "$chisel_arch" rustfmt_cargo-fmt cargo_cargo)"
chroot "$rootfs" cargo fmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" cargo fmt --help | grep -q 'This utility formats all bin and lib files of the current crate using rustfmt'
chroot "$rootfs" cargo fmt --help | grep -q 'Usage: cargo fmt'
