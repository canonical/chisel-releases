#!/usr/bin/env bash
# spellchecker: ignore rootfs
rootfs="$(install-slices cargo-1.97_cargo)"
# ln -s rustc-1.97 "$rootfs/usr/bin/rustc"  # not needed for help/version

chroot "$rootfs" cargo-1.97 --help | grep -q "Rust's package manager"
chroot "$rootfs" cargo-1.97 --version | grep -q 'cargo 1.97'