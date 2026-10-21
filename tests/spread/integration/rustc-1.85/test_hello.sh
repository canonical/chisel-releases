#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.85_rustc)"

cp testfiles/hello.rs "${rootfs}/hello.rs"

chroot "${rootfs}" rustc-1.85 /hello.rs -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from Rust!"
