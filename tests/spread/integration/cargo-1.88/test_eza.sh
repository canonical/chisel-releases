#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver resolv

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

slices=(
    cargo-1.88_cargo
    binutils_archiver # the zlib dependency requires ar
    ca-certificates_data # for HTTPS access to crates.io
)

rootfs="$(install-slices --arch "$chisel_arch" "${slices[@]}")"
ln -s gcc "$rootfs/usr/bin/cc"
ln -s rustc-1.88 "$rootfs/usr/bin/rustc"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null" && chmod +x "$rootfs/dev/null"

# We need DNS to fetch crates.io dependencies
mkdir -p "$rootfs/etc" && cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Enable apt source downloads
# NOTE: we need dpkg-dev to unpack the source
sed -i 's|^Types:.*|Types: deb deb-src|' /etc/apt/sources.list.d/ubuntu.sources
apt update && apt install -y dpkg-dev

# Download source
(
    cd "$rootfs" || exit 1
    apt source rust-eza -y
    mv rust-eza-* rust-eza
)

# Build
chroot "$rootfs" cargo-1.88 -Z unstable-options -C /rust-eza build

# Verify the built binary works
chroot "$rootfs" /rust-eza/target/debug/eza --help | grep -q "eza \[options\] \[files...\]"
touch "$rootfs/tmp/testfile"
chroot "$rootfs" /rust-eza/target/debug/eza /tmp | grep -q "testfile"