#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs resolv localtime postinst tzdata zoneinfo
rootfs="$(install-slices apt_apt-get)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"
# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

chroot "$rootfs" apt update

# Install tzdata in a non-interactive mode. This is a python dependency
mkdir -p "$rootfs/usr/share/zoneinfo/Etc/"
cp /usr/share/zoneinfo/Etc/UTC "$rootfs/usr/share/zoneinfo/Etc/UTC"
ln -s /usr/share/zoneinfo/Etc/UTC "$rootfs/etc/localtime"
chroot "$rootfs" apt install -y tzdata

# INstall python3.13 postinst dependencies
chroot "$rootfs" apt install -y grep

# Install python3.13
chroot "$rootfs" apt install python3.13 -y

chroot "${rootfs}/" python3.13 -c 'print("Hello, World!")' | grep -q "Hello, World!"

