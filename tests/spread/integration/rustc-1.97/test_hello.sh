#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc-1.97_rustc)"

cp testfiles/hello.rs "${rootfs}/hello.rs"

chroot "${rootfs}" rustc-1.97 /hello.rs -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from Rust!"
