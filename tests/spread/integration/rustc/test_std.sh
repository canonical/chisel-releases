#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc_rustc)"

cp testfiles/test_std.rs "${rootfs}"/test_std.rs

chroot "${rootfs}" rustc /test_std.rs -o /test_std
chroot "${rootfs}" /test_std
