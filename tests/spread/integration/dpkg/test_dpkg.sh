#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs getopt

# Basic smoke test for dpkg without maintainer scripts
rootfs="$(install-slices dpkg_dpkg)"

help=$(chroot "$rootfs" dpkg --help | head -n 1 || true)
echo "$help" | grep -q "Usage: dpkg"
version=$(chroot "$rootfs" dpkg --version | head -n1 || true)
echo "$version" | grep -q "Debian 'dpkg' package management program version"

# A sample deb file to install. Contains no dependencies or install scripts.
mkdir -p "${rootfs}/debs"
cp lsb-release.deb "${rootfs}/debs/"

# Run a smoke test for dpkg to ensure that it does not throw an error
chroot "$rootfs" dpkg --install -R /debs

# Verify that the package is installed
chroot "$rootfs" dpkg --get-selections | grep -q "lsb-release\s*install"
test -f "${rootfs}/usr/bin/lsb_release"

# Verify that the installed package's binary runs
cat "${rootfs}/usr/bin/lsb_release" | grep -q "#!/bin/sh"
cat "${rootfs}/usr/bin/lsb_release" | grep -q "Usage: lsb_release"
help=$(chroot "$rootfs" lsb_release --help 2>&1 || true)
echo "$help" | grep -q "getopt: not found"

# Remove the installed package
chroot "$rootfs" dpkg --remove lsb-release

# Verify that the package is removed
test -z "$(chroot "$rootfs" dpkg --get-selections)"
test ! -f "${rootfs}/usr/bin/lsb_release"

# Test --unpack
chroot "$rootfs" dpkg --unpack /debs/lsb-release.deb
test -f "${rootfs}/usr/bin/lsb_release"

# Test --purge
chroot "$rootfs" dpkg --purge lsb-release
test ! -f "${rootfs}/usr/bin/lsb_release"