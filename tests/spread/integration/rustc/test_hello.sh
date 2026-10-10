#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc_rustc)"

cp testfiles/hello.rs "${rootfs}/hello.rs"

chroot "${rootfs}" rustc /hello.rs -o /hello
chroot "${rootfs}" /hello | grep -q "Hello from Rust!"
