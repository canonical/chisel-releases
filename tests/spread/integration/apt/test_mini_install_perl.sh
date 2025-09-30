#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
else
    apt update
fi

source "$FILE_DIR"/apt_ci_shim.sh

## TESTS 
# spellchecker: ignore rootfs resolv coreutils
rootfs="$(install-slices apt_apt-get-mini)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Perl wants /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

chroot "$rootfs" apt update
chroot "$rootfs" apt install -y --no-install-recommends coreutils dpkg apt # bootstrap apt with itself
chroot "$rootfs" apt install -y perl
chroot "$rootfs" perl -e 'print "Hello, World!\n"' | grep -q "Hello, World!"
