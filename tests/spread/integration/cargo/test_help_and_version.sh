#!/usr/bin/env bash
# spellchecker: ignore rootfs
rootfs="$(install-slices cargo_cargo)"

chroot "$rootfs" cargo --help | grep -q "Rust's package manager"
chroot "$rootfs" cargo --version | grep -q 'cargo 1.93'