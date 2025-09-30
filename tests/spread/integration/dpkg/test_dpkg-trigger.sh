#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs Unincorp libc noawait

rootfs="$(install-slices dpkg_dpkg-trigger)"

# Check that dpkg-trigger runs and shows help
help=$(chroot "$rootfs" dpkg-trigger --help | head -n1 || true)
echo "$help" | grep -q "Usage: dpkg-trigger"
version=$(chroot "$rootfs" dpkg-trigger --version | head -n1 || true)
echo "$version" | grep -q "Debian dpkg-trigger package trigger utility version"

# No triggers exist yet, so --check-supported should report that
check_supported=$(chroot "$rootfs" dpkg-trigger --check-supported 2>&1 || true)
echo "$check_supported" | grep -q "trigger records not yet in existence"

# Create a trigger file
touch "$rootfs"/var/lib/dpkg/triggers/Unincorp
echo "systemd/noawait" > "$rootfs"/var/lib/dpkg/triggers/libc-upgrade

# Now --check-supported should report that triggers are supported
chroot "$rootfs" dpkg-trigger --check-supported

test -z "$(cat "$rootfs"/var/lib/dpkg/triggers/Unincorp || true)"

# Activate a trigger
chroot "$rootfs" dpkg-trigger \
    --by-package=systemd \
    libc-upgrade

# Check that the trigger was activated
cat "$rootfs"/var/lib/dpkg/triggers/Unincorp | grep -q "libc-upgrade systemd"
