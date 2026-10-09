#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.85_rustc)"

cp testfiles/test_std.rs "${rootfs}"/test_std.rs

chroot "${rootfs}" rustc-1.85 /test_std.rs -o /test_std
chroot "${rootfs}" /test_std
