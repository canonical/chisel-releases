#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

source "$FILE_DIR"/apt_ci_shim.sh

## TESTS 
# spellchecker: ignore rootfs resolv
rootfs="$(install-slices apt_apt-get)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"
# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

chroot "$rootfs" apt update
