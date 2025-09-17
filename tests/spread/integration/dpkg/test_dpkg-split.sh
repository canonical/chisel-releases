#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs urandom partsize

rootfs_deb="$(install-slices dpkg_dpkg-deb)"
# Create a sample file to split

mkdir -p "$rootfs_deb/large/DEBIAN"
mkdir -p "$rootfs_deb/large/usr/local/share"

dd if=/dev/urandom of="$rootfs_deb/large/usr/local/share/testfile.txt" bs=1K count=10

cat > "$rootfs_deb/large/DEBIAN/control" << EOF
Package: large
Version: 1.0
Section: custom
Priority: optional
Architecture: all
Maintainer: Test <test@test.com>
Description: A test package containing a large dummy file.
EOF

# Build the .deb package
chroot "$rootfs_deb" dpkg-deb --build /large

# Now test dpkg-split
rootfs_split="$(install-slices dpkg_dpkg-split)"

# Check that dpkg-split runs and shows help
chroot "${rootfs_split}/" dpkg-split --help | grep -q "Usage: dpkg-split"
chroot "${rootfs_split}/" dpkg-split --version | head -n 1 | grep -q "Debian 'dpkg-split' package split/join tool; version"

# Move the .deb package to the root for easier access
mv "$rootfs_deb/large.deb" "$rootfs_split/large.deb"

# Split the test file into parts of 1 KiB each
chroot "$rootfs_split" dpkg-split \
    --split --partsize 2 \
    /large.deb

# Verify that parts were created
# We expect files named large.1of*.deb, large.2of*.deb, etc.
n_parts=$(find "$rootfs_split" -maxdepth 1 -type f -name 'large.*of*.deb' | wc -l)
if [[ "$n_parts" -lt 2 ]]; then
    echo "Error: Expected at least 2 parts, found $n_parts"
    exit 1
fi
first_part=$(find "$rootfs_split" -maxdepth 1 -type f -name 'large.1of*.deb' -printf "%P\n" -quit)

# Display information about one of the parts
info=$(chroot "$rootfs_split" dpkg-split --info "$first_part")
echo "$info" | grep -q "Part of package: *large"
echo "$info" | grep -q "Part number: *1/$n_parts"

# Join the parts back together into a single file
sha_before=$(sha256sum "$rootfs_split/large.deb" | awk '{print $1}')

all_parts=$(find "$rootfs_split" -maxdepth 1 -type f -name 'large.*of*.deb' -printf "%P\n" | sort | xargs)
# shellcheck disable=SC2086
chroot "$rootfs_split" dpkg-split --join $all_parts

# Verify that the joined file matches the original
sha_after=$(sha256sum "$rootfs_split/large.deb" | awk '{print $1}')
if [[ "$sha_before" != "$sha_after" ]]; then
    echo "Error: SHA256 mismatch after joining parts"
    exit 1
fi
