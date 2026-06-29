#!/usr/bin/env bash
# spellchecker: ignore rootfs clippy

# test clippy-driver slice
rootfs="$(install-slices rust-clippy_clippy-driver)"
chroot "$rootfs" clippy-driver --version | grep -q 'clippy 0.1.93'
chroot "$rootfs" clippy-driver --help | grep -q 'Checks a file to catch common mistakes and improve your Rust code.'

# test clippy slice
rootfs="$(install-slices rust-clippy_clippy)"
# test that installing clippy also makes clippy-driver available
chroot "$rootfs" clippy-driver --version | grep -q 'clippy 0.1.93'
# also test clippy directly
chroot "$rootfs" cargo-clippy --version | grep -q 'clippy 0.1.93'
chroot "$rootfs" cargo-clippy --help | grep -q 'Checks a package to catch common mistakes and improve your Rust code.'
# finally, test with `cargo clippy`
rootfs="$(install-slices rust-clippy_clippy cargo_cargo)"
chroot "$rootfs" cargo clippy --version | grep -q 'clippy 0.1.93'
chroot "$rootfs" cargo clippy --help | grep -q 'Checks a package to catch common mistakes and improve your Rust code.'
