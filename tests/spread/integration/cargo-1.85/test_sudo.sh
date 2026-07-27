#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver resolv libpam0g

slices=(
    cargo-1.85_cargo
    binutils_archiver # the zlib dependency requires ar
    ca-certificates_data # for HTTPS access to crates.io
    libpam0g-dev_libs  # sudo-rs dependency
)

rootfs="$(install-slices "${slices[@]}")"
ln -s rustc-1.85 "$rootfs/usr/bin/rustc"

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
    apt source rust-sudo-rs -y
    mv rust-sudo-rs-* rust-sudo-rs
)

# Build
chroot "$rootfs" cargo-1.85 -Z unstable-options -C /rust-sudo-rs build

# Verify the built binary works
(chroot "$rootfs" /rust-sudo-rs/target/debug/sudo --help 2>&1 || true) \
    | grep -q "sudo - run commands as another user"
