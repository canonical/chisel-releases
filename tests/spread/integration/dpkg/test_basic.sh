#!/bin/bash
#spellchecker: ignore rootfs diffutils

# basic smoke test for dpkg without maintainer scripts
rootfs="$(install-slices dpkg_bins)"

# Get a sample deb file to install. Contains no dependencies or install scripts.
apt update
mkdir -p "$rootfs/debs"
pushd "$rootfs/debs" || exit 1
apt download lsb-release
popd || exit 1

# Run a smoke test for dpkg to ensure that it does not throw an error
chroot "$rootfs" dpkg --install -R /debs
