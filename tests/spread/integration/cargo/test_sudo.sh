#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver resolv libpam0g
slices=(
    cargo_cargo
    binutils_archiver # the zlib dependency requires ar
    ca-certificates_data # for HTTPS access to crates.io
    libpam0g-dev_libs  # sudo-rs dependency
)

rootfs="$(install-slices "${slices[@]}")"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null" && chmod +x "$rootfs/dev/null"

# We need DNS to fetch crates.io dependencies
mkdir -p "$rootfs/etc" && cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Enable apt source downloads
# NOTE: we need dpkg-dev to unpack the source
sed -i 's|^Types:.*|Types: deb deb-src|' /etc/apt/sources.list.d/ubuntu.sources
apt update && apt install -y dpkg-dev git

# Download source
(
    cd "$rootfs" || exit 1
    apt source rust-sudo-rs -y
    mv rust-sudo-rs-* rust-sudo-rs
)

# noble's sudo-rs 0.2.2 predates the upstream s390x fix; see the patch header
git -C "$rootfs/rust-sudo-rs" apply "$PWD/testfiles/sudo-rs-sigaction.patch"

# Build
chroot "$rootfs" cargo -Z unstable-options -C /rust-sudo-rs build

# Verify the built binary works
(chroot "$rootfs" /rust-sudo-rs/target/debug/sudo --help 2>&1 || true) \
    | grep -q "sudo - run commands as another user"
