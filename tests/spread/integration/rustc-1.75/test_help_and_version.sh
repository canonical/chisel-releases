#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

rootfs="$(install-slices rustc-1.75_rustc)"
chroot "${rootfs}/" rustc-1.75 --help | grep -q "Usage: rustc"
chroot "${rootfs}/" rustc-1.75 --version | grep -q 'rustc 1.75'
