#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

rootfs="$(install-slices rustc_rustc)"
chroot "${rootfs}/" rustc --help | grep -q "Usage: rustc"
chroot "${rootfs}/" rustc --version | grep -q 'rustc 1.75'
