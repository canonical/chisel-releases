#!/usr/bin/env bash
# spellchecker: ignore rootfs rustfmt

# test rustfmt slice
rootfs="$(install-slices rustfmt_rustfmt)"
chroot "$rootfs" rustfmt --version | grep -Fiq 'rustfmt 1.8.0'
chroot "$rootfs" rustfmt --help | grep -Fq 'Format Rust code'
chroot "$rootfs" rustfmt --help | grep -Fq 'usage: rustfmt'

# test cargo-fmt slice
rootfs="$(install-slices rustfmt_cargo-fmt)"
# installing cargo-fmt also makes rustfmt available
chroot "$rootfs" cargo-fmt --version | grep -Fiq 'rustfmt 1.8.0'
chroot "$rootfs" cargo-fmt --help | grep -Fq 'This utility formats all bin and lib files of the current crate using rustfmt'
chroot "$rootfs" cargo-fmt --help | grep -Fq 'Usage: cargo fmt'

# test with `cargo fmt`
rootfs="$(install-slices rustfmt_cargo-fmt cargo_cargo)"
chroot "$rootfs" cargo fmt --version | grep -Fiq 'rustfmt 1.8.0'
chroot "$rootfs" cargo fmt --help | grep -Fq 'This utility formats all bin and lib files of the current crate using rustfmt'
chroot "$rootfs" cargo fmt --help | grep -Fq 'Usage: cargo fmt'
