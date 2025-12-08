#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

rootfs="$(install-slices rustc-1.84_rustc)"
chroot "${rootfs}/" rustc-1.84 --help | grep -q "Usage: rustc"
chroot "${rootfs}/" rustc-1.84 --version | grep -q 'rustc 1.84'
