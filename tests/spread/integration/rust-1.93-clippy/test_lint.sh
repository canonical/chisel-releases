#!/usr/bin/env bash
# spellchecker: ignore rootfs clippy

rootfs="$(install-slices rust-1.93-clippy_clippy-driver)"

mkdir -p "$rootfs/tmp"
cp -r testfiles/hello_clippy "$rootfs"

# Verify clippy reports the expected lint warning
chroot "$rootfs" /usr/lib/rust-1.93/bin/clippy-driver \
  --emit=metadata --out-dir /tmp \
  /hello_clippy/src/main.rs 2>&1 |
  grep -Fq "clippy::len_zero"

# Test clippy slice: verify that cargo-clippy triggers the same lint warning
rootfs="$(install-slices rust-1.93-clippy_clippy cargo-1.93_cargo)"
ln -s /usr/lib/rust-1.93/bin/cargo-clippy "$rootfs/usr/bin/cargo-clippy"
ln -s /usr/lib/rust-1.93/bin/clippy-driver "$rootfs/usr/bin/clippy-driver"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
# shellcheck disable=SC2064
trap "umount '$rootfs/proc'" EXIT
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"
cp -r testfiles/hello_clippy "$rootfs"
chroot "$rootfs" cargo-1.93 -Z unstable-options -C /hello_clippy clippy 2>&1 |
  grep -Fq "clippy::len_zero"
