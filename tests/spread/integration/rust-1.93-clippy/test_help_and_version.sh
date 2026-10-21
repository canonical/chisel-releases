#!/usr/bin/env bash
# spellchecker: ignore rootfs clippy

# test clippy-driver slice
rootfs="$(install-slices rust-1.93-clippy_clippy-driver)"
chroot "$rootfs" /usr/lib/rust-1.93/bin/clippy-driver --version | grep -Fiq 'clippy 0.1.93'
chroot "$rootfs" /usr/lib/rust-1.93/bin/clippy-driver --help | grep -Fq 'Checks a file to catch common mistakes and improve your Rust code.'

# test clippy slice
rootfs="$(install-slices rust-1.93-clippy_clippy)"
# test that installing clippy also makes clippy-driver available
chroot "$rootfs" /usr/lib/rust-1.93/bin/clippy-driver --version | grep -Fiq 'clippy 0.1.93'

# also test clippy directly
chroot "$rootfs" /usr/lib/rust-1.93/bin/cargo-clippy --version | grep -Fiq 'clippy 0.1.93'
chroot "$rootfs" /usr/lib/rust-1.93/bin/cargo-clippy --help | grep -Fq 'Checks a package to catch common mistakes and improve your Rust code.'

# finally, test with `cargo clippy`
rootfs="$(install-slices rust-1.93-clippy_clippy cargo-1.93_cargo)"
ln -s cargo-1.93 "$rootfs/usr/bin/cargo"
ln -s /usr/lib/rust-1.93/bin/cargo-clippy "$rootfs/usr/bin/cargo-clippy"
ln -s /usr/lib/rust-1.93/bin/clippy-driver "$rootfs/usr/bin/clippy-driver"
chroot "$rootfs" cargo clippy --version | grep -Fiq 'clippy 0.1.93'
chroot "$rootfs" cargo clippy --help | grep -Fq 'Checks a package to catch common mistakes and improve your Rust code.'
