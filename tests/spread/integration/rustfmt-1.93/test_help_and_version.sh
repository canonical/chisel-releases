#!/usr/bin/env bash
# spellchecker: ignore rootfs rustfmt

# test rustfmt slice
rootfs="$(install-slices rustfmt-1.93_rustfmt)"
# somewhat unexpectedly, the `rustfmt` version associated with Rust 1.93 is NOT 1.93
# instead, it has its own version number; for Rust 1.93, that's 1.8.0
chroot "$rootfs" /usr/lib/rust-1.93/bin/rustfmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" /usr/lib/rust-1.93/bin/rustfmt --help | grep -q 'Format Rust code'

# test cargo-fmt slice
rootfs="$(install-slices rustfmt-1.93_cargo-fmt)"
# installing cargo-fmt also makes rustfmt available
chroot "$rootfs" /usr/lib/rust-1.93/bin/rustfmt --version | grep -q 'rustfmt 1.8.0'
chroot "$rootfs" /usr/lib/rust-1.93/bin/cargo-fmt --help | grep -q 'This utility formats all bin and lib files of the current crate using rustfmt'

# test with `cargo fmt`
rootfs="$(install-slices rustfmt-1.93_cargo-fmt cargo-1.93_cargo)"
ln -s cargo-1.93 "$rootfs/usr/bin/cargo"
ln -s /usr/lib/rust-1.93/bin/cargo-fmt "$rootfs/usr/bin/cargo-fmt"
ln -s /usr/lib/rust-1.93/bin/rustfmt "$rootfs/usr/bin/rustfmt"
chroot "$rootfs" cargo fmt --help | grep -q 'This utility formats all bin and lib files of the current crate using rustfmt'
