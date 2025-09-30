#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

source "$FILE_DIR"/apt_ci_shim.sh

## TESTS 
# spellchecker: ignore rootfs resolv localtime postinst tzdata zoneinfo
rootfs="$(install-slices apt_apt-get)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Python wants /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

chroot "$rootfs" apt update
chroot "$rootfs" apt install -y python3.13
chroot "$rootfs" python3.13 -c 'print("Hello, World!")' | grep -q "Hello, World!"
