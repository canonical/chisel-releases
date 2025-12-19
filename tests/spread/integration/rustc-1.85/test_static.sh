#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "$chisel_arch" rustc-1.85_bins)"
ln -s gcc "$rootfs/usr/bin/cc"

cp testfiles/greeter.rs "$rootfs/greeter.rs"
cp testfiles/use_greeter.c "$rootfs/use_greeter.c"

chroot "$rootfs" rustc-1.85 /greeter.rs --crate-type staticlib -o /libgreeter.a
test -f "$rootfs/libgreeter.a"

# Compile and link C program against the static library
chroot "$rootfs" gcc /use_greeter.c -L/ -lgreeter -o /use_greeter
chroot "$rootfs" /use_greeter | grep -q "Hello to C from Rust 1.85 static library!"
