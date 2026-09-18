#!/usr/bin/env bash
# spellchecker: ignore rootfs cargo

rootfs="$(install-slices cargo-1.93_cargo rustc-1.93_rustdoc)"

# Create minimal /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_crate "$rootfs"

# The versioned package only ships versioned names, and cargo looks for the
# unversioned "rustc"/"rustdoc". Point it at the real binaries with full
# paths, replicating what the deb's /usr/bin/cargo-1.93 wrapper does.
RUSTC=/usr/bin/rustc-1.93 RUSTDOC=/usr/bin/rustdoc-1.93 chroot "$rootfs" /usr/bin/cargo-1.93 doc --manifest-path /hello_crate/Cargo.toml
test -f "$rootfs/hello_crate/target/doc/hello/index.html"
test -f "$rootfs/hello_crate/target/doc/greeter/index.html"
