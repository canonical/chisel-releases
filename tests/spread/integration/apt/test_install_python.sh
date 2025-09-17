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

# Python wants /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

chroot "$rootfs" apt update
chroot "$rootfs" apt install python3.13 -y
chroot "$rootfs" python3.13 -c 'print("Hello, World!")' | grep -q "Hello, World!"

