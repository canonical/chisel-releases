#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.93_rustc)"

cp testfiles/hello.rs "${rootfs}/hello.rs"

chroot "${rootfs}" rustc-1.93 /hello.rs -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from Rust!"
