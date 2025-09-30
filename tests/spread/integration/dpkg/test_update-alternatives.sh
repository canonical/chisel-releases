#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs urandom partsize

rootfs="$(install-slices dpkg_update-alternatives)"

# Check that update-alternatives runs and shows help
help=$(chroot "$rootfs" update-alternatives --help | head -n1 || true)
echo "$help" | grep -q "Usage: update-alternatives"
version=$(chroot "$rootfs" update-alternatives --version | head -n1 || true)
echo "$version" | grep -q "update-alternatives version"

# Create some dummy files to manage alternatives for
mkdir -p "$rootfs/usr/bin"
echo -e '#!/bin/sh\necho "This is less"' > "$rootfs/usr/bin/less"
echo -e '#!/bin/sh\necho "This is more"' > "$rootfs/usr/bin/more"
chmod +x "$rootfs/usr/bin/less"
chmod +x "$rootfs/usr/bin/more"

# Install alternatives for pager
chroot "$rootfs" update-alternatives --install /usr/bin/pager pager /usr/bin/less 10
chroot "$rootfs" update-alternatives --install /usr/bin/pager pager /usr/bin/more 5

# Check that the alternatives were installed correctly
test "$(readlink -f "$rootfs/usr/bin/pager" || true)" = "/usr/bin/less"
test "$(readlink -f "$rootfs/etc/alternatives/pager" || true)" = "/usr/bin/less"

status=$(chroot "$rootfs" update-alternatives --query pager || true)
echo "$status" | grep -q "Name: pager"
echo "$status" | grep -q "Status: auto"
echo "$status" | grep -q "Best: /usr/bin/less"
echo "$status" | grep -q "Value: /usr/bin/less"
echo "$status" | grep -q "Alternative: /usr/bin/less"
echo "$status" | grep -q "Priority: 10"
echo "$status" | grep -q "Alternative: /usr/bin/more"
echo "$status" | grep -q "Priority: 5"
