#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs

rootfs="$(install-slices dpkg_dpkg-divert)"

# Check that dpkg-divert runs and shows help
help=$(chroot "$rootfs" dpkg-divert --help | head -n1 || true)
echo "$help" | grep -q "Usage: dpkg-divert"
version=$(chroot "$rootfs" dpkg-divert --version | head -n1 || true)
echo "$version" | grep -q "Debian dpkg-divert version"
chroot "$rootfs" dpkg-divert --help

# Create a dummy file to divert
mkdir -p "$rootfs/usr/bin"
echo -e '#!/bin/sh\necho "This is foo"' > "$rootfs/usr/bin/foo"
chmod +x "$rootfs/usr/bin/foo"

# Divert the file
chroot "$rootfs" dpkg-divert --add --rename --divert /usr/bin/foo.distrib /usr/bin/foo \
    | grep -q "Adding 'local diversion of /usr/bin/foo to /usr/bin/foo.distrib'"
test -f "$rootfs/usr/bin/foo.distrib"
test ! -f "$rootfs/usr/bin/foo"

# Check that the diversion is listed
diversion_list=$(chroot "$rootfs" dpkg-divert --list /usr/bin/foo || true)
echo "$diversion_list" | grep -q "local diversion of /usr/bin/foo to /usr/bin/foo.distrib"

# Check the truename command
truename=$(chroot "$rootfs" dpkg-divert --truename /usr/bin/foo || true)
echo "$truename" | grep -q "/usr/bin/foo.distrib"

# Check the listpackage command
listpackage=$(chroot "$rootfs" dpkg-divert --listpackage /usr/bin/foo || true)
echo "$listpackage" | grep -q "LOCAL"

# Remove the diversion
chroot "$rootfs" dpkg-divert --remove --rename /usr/bin/foo \
    | grep -q "Removing 'local diversion of /usr/bin/foo to /usr/bin/foo.distrib'"
test -f "$rootfs/usr/bin/foo"
test ! -f "$rootfs/usr/bin/foo.distrib"

# Check that the diversion is no longer listed
diversion_list=$(chroot "$rootfs" dpkg-divert --list /usr/bin/foo || true)
test -z "$diversion_list"
