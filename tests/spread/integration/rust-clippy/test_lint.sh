#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc clippy

arch=$(uname -m)
case "${arch}" in
aarch64) chisel_arch="arm64" ;;
x86_64) chisel_arch="amd64" ;;
*)
  echo "Unsupported architecture: ${arch}"
  exit 1
  ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rust-clippy_clippy cargo_cargo)"

# Create minimal /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_clippy "$rootfs"

# Verify clippy runs and reports the expected lint warning
chroot "$rootfs" cargo -C /hello_clippy clippy 2>&1 |
  grep -q "clippy::len_zero"
