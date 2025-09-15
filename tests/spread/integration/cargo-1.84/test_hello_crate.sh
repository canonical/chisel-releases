#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs rustc binutils libgcc

arch=$(uname -m)-linux-gnu
slices=(
    cargo-1.84_cargo
    rustc-1.84_rustc
    gcc-14-"${arch//_/-}"_gcc-14
    binutils-"${arch//_/-}"_linker
    libgcc-14-dev_libgcc
)
rootfs="$(install-slices "${slices[@]}")"
ln -s rustc-1.84 "${rootfs}"/usr/bin/rustc
ln -s cargo-1.84 "${rootfs}"/usr/bin/cargo
ln -s "${arch}"-gcc-14 "${rootfs}"/usr/bin/cc
ln -s "${arch}"-ld "${rootfs}"/usr/bin/ld

# Create minimal /dev/null 
mkdir -p "${rootfs}"/dev
touch "${rootfs}"/dev/null
chmod +x "${rootfs}"/dev/null

# Use cargo to create a library with a greeter function, then build it as
# a separate crate and use it from a binary crate.

mkdir -p "${rootfs}"/hello_crate
cat > "${rootfs}"/hello_crate/Cargo.toml <<EOF
[workspace]
members = [ "greeter", "hello" ]
resolver = "2"
EOF

mkdir -p "${rootfs}"/hello_crate/greeter/src
cat > "${rootfs}"/hello_crate/greeter/Cargo.toml <<EOF
[package]
name = "greeter"
version = "0.1.0"
edition = "2021"
EOF

cat > "${rootfs}"/hello_crate/greeter/src/lib.rs <<EOF
pub fn greet() -> String {
    "Hello, world!".to_string()
}
EOF

mkdir -p "${rootfs}"/hello_crate/hello/src
cat > "${rootfs}"/hello_crate/hello/Cargo.toml <<EOF
[package]
name = "hello"
version = "0.1.0"
edition = "2021"
[dependencies]
greeter = { path = "../greeter" }
EOF

cat > "${rootfs}"/hello_crate/hello/src/main.rs <<EOF
use greeter::greet;
fn main() {
    println!("{}", greet());
}
EOF

chroot "${rootfs}" cargo -Z unstable-options -C /hello_crate build --workspace
chroot "${rootfs}" ./hello_crate/target/debug/hello | grep -q "Hello, world!"