#!/usr/bin/env bash
# spellchecker: ignore rootfs rustfmt

# test rustfmt slice
rootfs="$(install-slices rustfmt_rustfmt)"
chroot "$rootfs" rustfmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" rustfmt --help | grep -q 'Format Rust code'
chroot "$rootfs" rustfmt --help | grep -q 'usage: rustfmt'

# test cargo-fmt slice
rootfs="$(install-slices rustfmt_cargo-fmt)"
# installing cargo-fmt also makes rustfmt available
chroot "$rootfs" cargo-fmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" cargo-fmt --help | grep -q 'This utility formats all bin and lib files of the current crate using rustfmt'
chroot "$rootfs" cargo-fmt --help | grep -q 'Usage: cargo fmt'

# test with `cargo fmt`
rootfs="$(install-slices rustfmt_cargo-fmt cargo_cargo)"
chroot "$rootfs" cargo fmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" cargo fmt --help | grep -q 'This utility formats all bin and lib files of the current crate using rustfmt'
chroot "$rootfs" cargo fmt --help | grep -q 'Usage: cargo fmt'
