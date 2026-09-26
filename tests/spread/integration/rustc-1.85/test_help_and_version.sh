#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.85_rustc)"

chroot "${rootfs}/" rustc-1.85 --help | grep -q "Usage: rustc"
chroot "${rootfs}/" rustc-1.85 --version | grep -q 'rustc 1.85'
