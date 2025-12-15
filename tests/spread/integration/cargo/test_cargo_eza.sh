#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver resolv

arch=$(uname -m)
case "${arch}" in
    aarch64) chisel_arch="arm64" ;;
    x86_64) chisel_arch="amd64" ;;
    *) echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

slices=(
    cargo_cargo
    binutils_archiver # the zlib dependency requires ar
    ca-certificates_data # for HTTPS access to crates.io
)

rootfs="$(install-slices --arch "$chisel_arch" "${slices[@]}")"
ln -s gcc "$rootfs/usr/bin/cc"

# Create minimal /dev/null 
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# We need DNS to fetch crates.io dependencies
mkdir -p "$rootfs/etc"
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Clone eza source code
url="https://github.com/eza-community/eza.git"
tag="v0.23.3"
git clone "$url" "$rootfs/eza" -b "$tag" --single-branch

function checksum() {
    (
        cd "$1" || exit 1;
        find . -path '*/.git' -prune -o -type f -print0 | \
            sort -z | xargs -0 sha256sum | \
            sha256sum | cut -d' ' -f1;
    )
}

sha_expected="2c16e92954808f312ce16a9b5b0b9639e0c288910d6631a4240713c33f997705"
sha_actual=$(checksum "$rootfs/eza")
if [ "$sha_actual" != "$sha_expected" ]; then
    echo "SHA256 mismatch for eza source tree: expected $sha_expected, got $sha_actual"
    exit 1
fi

# Build
chroot "$rootfs" cargo -Z unstable-options -C /eza build

# Run the built eza binary to verify it works
chroot "$rootfs" /eza/target/debug/eza --help | grep -q "eza \[options\] \[files...\]"
touch "$rootfs/tmp/testfile"
chroot "$rootfs" /eza/target/debug/eza /tmp | grep -q "testfile"
