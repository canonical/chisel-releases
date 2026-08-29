#!/usr/bin/env bash
# spellchecker: ignore rootfs rustdoc

rootfs="$(install-slices rustc_rustdoc)"

chroot "$rootfs" rustdoc --version | grep -Fiq 'rustdoc 1.93'
chroot "$rootfs" rustdoc --help | grep -Fq 'rustdoc [options] <input>'

cp testfiles/hello.rs "$rootfs/hello.rs"
chroot "$rootfs" rustdoc /hello.rs -o /doc-out
test -f "$rootfs/doc-out/hello/index.html"
