#!/usr/bin/env bash
# spellchecker: ignore rootfs miri

# test miri binary (pulled in via cargo-miri deps)
rootfs="$(install-slices rust-miri_cargo-miri)"
# miri is a thin wrapper around rustc, so --version prints the rustc version
RUSTC_BOOTSTRAP=1 chroot "$rootfs" /usr/lib/rust-1.93/bin/miri --version | grep -Fiq 'rustc 1.93'

# test cargo-unstable-miri wrapper (sets RUSTC_BOOTSTRAP=1 itself)
chroot "$rootfs" cargo-unstable-miri --version | grep -Fiq 'miri'
chroot "$rootfs" cargo-unstable-miri --help | grep -Fiq 'miri'
