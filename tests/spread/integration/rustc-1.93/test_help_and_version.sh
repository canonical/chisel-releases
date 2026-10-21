#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.93_rustc)"

chroot "${rootfs}/" rustc-1.93 --help | grep -q "Usage: rustc"
chroot "${rootfs}/" rustc-1.93 --version | grep -q 'rustc 1.93'
