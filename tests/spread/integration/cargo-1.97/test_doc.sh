#!/usr/bin/env bash
# spellchecker: ignore rootfs cargo

rootfs="$(install-slices cargo-1.97_cargo rustc-1.97_rustdoc)"

# Create minimal /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

cp -r testfiles/hello_crate "$rootfs"

# The versioned package only ships versioned names, and cargo looks for the
# unversioned "rustc"/"rustdoc". Point it at the real binaries with full
# paths, replicating what the deb's /usr/bin/cargo-1.97 wrapper does.
RUSTC=/usr/bin/rustc-1.97 RUSTDOC=/usr/bin/rustdoc-1.97 chroot "$rootfs" /usr/bin/cargo-1.97 doc --manifest-path /hello_crate/Cargo.toml
test -f "$rootfs/hello_crate/target/doc/hello/index.html"
test -f "$rootfs/hello_crate/target/doc/greeter/index.html"
