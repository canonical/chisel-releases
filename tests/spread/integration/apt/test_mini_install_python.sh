#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs resolv coreutils
rootfs="$(install-slices apt_apt-get-mini)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Python wants /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

chroot "$rootfs" apt update
chroot "$rootfs" apt install -y --no-install-recommends coreutils dpkg apt # bootstrap apt with itself
chroot "$rootfs" apt install python3.13 -y
chroot "$rootfs" python3.13 -c 'print("Hello, World!")' | grep -q "Hello, World!"
