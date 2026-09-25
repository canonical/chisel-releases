#!/usr/bin/env bash
# spellchecker: ignore rootfs rustc
rootfs="$(install-slices rustc_rustc)"

cp testfiles/greeter.rs "$rootfs/greeter.rs"
cp testfiles/use_greeter.c "$rootfs/use_greeter.c"

chroot "$rootfs" rustc /greeter.rs --crate-type staticlib -o /libgreeter.a
test -f "$rootfs/libgreeter.a"

# Compile and link C program against the static library
chroot "$rootfs" gcc /use_greeter.c -L/ -lgreeter -o /use_greeter
chroot "$rootfs" /use_greeter | grep -q "Hello to C from Rust static library!"
