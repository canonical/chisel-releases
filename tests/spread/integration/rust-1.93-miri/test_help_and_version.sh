#!/usr/bin/env bash
# spellchecker: ignore rootfs miri

# test miri slice
rootfs="$(install-slices rust-1.93-miri_miri)"
# miri is a thin wrapper around rustc, so --version prints the rustc version
RUSTC_BOOTSTRAP=1 chroot "$rootfs" /usr/lib/rust-1.93/bin/miri --version | grep -q 'rustc 1.93'

# test cargo-miri slice
rootfs="$(install-slices rust-1.93-miri_cargo-miri)"
# miri binary is pulled in via cargo-miri deps
RUSTC_BOOTSTRAP=1 chroot "$rootfs" /usr/lib/rust-1.93/bin/miri --version | grep -q 'rustc 1.93'
# the wrapper sets RUSTC_BOOTSTRAP=1 itself and prints the actual miri version
chroot "$rootfs" /usr/bin/cargo-1.93-unstable-miri --version | grep -q 'miri'
chroot "$rootfs" /usr/bin/cargo-1.93-unstable-miri --help | grep -q -i 'miri'
