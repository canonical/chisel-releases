#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.93_rustc)"

cp testfiles/test_std.rs "${rootfs}"/test_std.rs

chroot "${rootfs}" rustc-1.93 /test_std.rs -o /test_std
chroot "${rootfs}" /test_std
