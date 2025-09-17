#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs resolv localtime postinst tzdata zoneinfo
rootfs="$(install-slices apt_apt-get)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

chroot "$rootfs" apt update
chroot "$rootfs" apt install -y lua5.4
chroot "$rootfs" lua5.4 -e 'print("Hello, World!")' | grep -q "Hello, World!"
