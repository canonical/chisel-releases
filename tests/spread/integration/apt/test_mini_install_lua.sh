#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

source "$FILE_DIR"/apt_ci_shim.sh

## TESTS 
# spellchecker: ignore rootfs resolv localtime postinst tzdata zoneinfo
rootfs="$(install-slices apt_apt-get-mini)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Although Lua doesn't need /dev/null, apt bootstrapping does
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

chroot "$rootfs" apt update
chroot "$rootfs" apt install -y --no-install-recommends coreutils dpkg apt # bootstrap apt with itself
chroot "$rootfs" apt install -y lua5.4
chroot "$rootfs" lua5.4 -e 'print("Hello, World!")' | grep -q "Hello, World!"
