#!/usr/bin/env bash
# spellchecker: ignore rootfs rustdoc

rootfs="$(install-slices rustc-1.97_rustdoc)"

# the unversioned /usr/bin/rustdoc is not part of the rustc-1.97 package
chroot "$rootfs" rustdoc-1.97 --version | grep -Fiq 'rustdoc 1.97'
chroot "$rootfs" /usr/lib/rust-1.97/bin/rustdoc --help | grep -Fq 'rustdoc [options] <input>'

cp testfiles/hello.rs "$rootfs/hello.rs"
chroot "$rootfs" rustdoc-1.97 /hello.rs -o /doc-out
test -f "$rootfs/doc-out/hello/index.html"
