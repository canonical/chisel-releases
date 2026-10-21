#!/usr/bin/env bash
# spellchecker: ignore rootfs
rootfs="$(install-slices cargo-1.85_cargo)"
# ln -s rustc-1.85 "$rootfs/usr/bin/rustc"  # not needed for help/version

chroot "$rootfs" cargo-1.85 --help | grep -q "Rust's package manager"
chroot "$rootfs" cargo-1.85 --version | grep -q 'cargo 1.85'