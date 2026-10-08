#!/usr/bin/env bash
# spellchecker: ignore rootfs rustfmt

source ./shared.sh
# test rustfmt slice
rootfs="$(install-slices rustfmt-1.97_rustfmt)"
# somewhat unexpectedly, the `rustfmt` version associated with Rust 1.97 is NOT 1.97
# instead, it has its own version number; for Rust 1.97, that's 1.9.0
chroot "$rootfs" /usr/lib/rust-1.97/bin/rustfmt --version | grep -Fiq 'rustfmt 1.9.0'
chroot "$rootfs" /usr/lib/rust-1.97/bin/rustfmt --help | grep -Fq 'Format Rust code'

# test cargo-fmt slice
rootfs="$(install-slices rustfmt-1.97_cargo-fmt)"
mount_proc
# installing cargo-fmt also makes rustfmt available
chroot "$rootfs" /usr/lib/rust-1.97/bin/rustfmt --version | grep -Fiq 'rustfmt 1.9.0'
chroot "$rootfs" /usr/lib/rust-1.97/bin/cargo-fmt --help | grep -Fq 'This utility formats all bin and lib files of the current crate using rustfmt'

# test with `cargo fmt`
rootfs="$(install-slices rustfmt-1.97_cargo-fmt cargo-1.97_cargo)"
mount_proc
ln -s cargo-1.97 "$rootfs/usr/bin/cargo"
ln -s /usr/lib/rust-1.97/bin/cargo-fmt "$rootfs/usr/bin/cargo-fmt"
ln -s /usr/lib/rust-1.97/bin/rustfmt "$rootfs/usr/bin/rustfmt"
chroot "$rootfs" cargo fmt --help | grep -Fq 'This utility formats all bin and lib files of the current crate using rustfmt'
