#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs

# Basic smoke test for dpkg without maintainer scripts
rootfs="$(install-slices dpkg_bins)"

# A sample deb file to install. Contains no dependencies or install scripts.
mkdir -p "${rootfs}/debs"
cp lsb-release.deb "${rootfs}/debs/"

# Run a smoke test for dpkg to ensure that it does not throw an error
chroot "${rootfs}/" dpkg --install -R /debs
