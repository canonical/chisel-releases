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
touch "$rootfs/dev"/null
chmod +x "$rootfs/dev"/null

# We need DNS to fetch crates.io dependencies
mkdir -p "$rootfs/etc"
cp /etc/resolv.conf "$rootfs/etc"/resolv.conf

# Clone cargo source
version_string=$(chroot "$rootfs" cargo --version)
# cargo 1.84.1 (66221abde 2024-11-19)
sha=${version_string#* (}
sha=${sha%% *}
url="https://github.com/rust-lang/cargo.git"

git clone "$url" "$rootfs"/cargo -b "master" --single-branch
git -C "$rootfs"/cargo reset --hard "$sha"

function checksum() {
    (
        cd "$1" || exit 1;
        find . -path '*/.git' -prune -o -type f -print0 | \
            sort -z | xargs -0 sha256sum | \
            sha256sum | cut -d' ' -f1;
    )
}

sha_expected="9f128293cbd163ab0a449b68d5c5b7ec938b87793935f9480f83677bea6c96f3"
sha_actual=$(checksum "$rootfs/cargo")
if [ "$sha_actual" != "$sha_expected" ]; then
    echo "SHA256 mismatch for cargo source tree: expected $sha_expected, got $sha_actual"
    exit 1
fi

# TODO: The full build fails because it needs libopenssl-dev which we don't have
#       a slice for so we just build the build plan to verify that cargo itself
#       works
chroot "$rootfs" cargo \
    -Z unstable-options \
    -C /cargo \
    build \
    -j1 \
    --build-plan > "$rootfs/build-plan.json"
cat "$rootfs/build-plan.json" | jq -r '.invocations[].package_name' | grep -q "^cargo$"
