#!/usr/bin/env bash
# spellchecker: ignore rootfs rustdoc

rootfs="$(install-slices rustc-1.93_rustdoc)"

# the unversioned /usr/bin/rustdoc is not part of the rustc-1.93 package
chroot "$rootfs" rustdoc-1.93 --version | grep -Fiq 'rustdoc 1.93'
chroot "$rootfs" /usr/lib/rust-1.93/bin/rustdoc --help | grep -Fq 'rustdoc [options] <input>'

cp testfiles/hello.rs "$rootfs/hello.rs"
chroot "$rootfs" rustdoc-1.93 /hello.rs -o /doc-out
test -f "$rootfs/doc-out/hello/index.html"
