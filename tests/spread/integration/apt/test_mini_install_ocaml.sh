#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs resolv localtime postinst tzdata zoneinfo
rootfs="$(install-slices apt_apt-get-mini)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# # Ocaml wants /dev/null
# mkdir -p "$rootfs/dev"
# touch "$rootfs/dev/null"
# chmod +x "$rootfs/dev/null"

# chroot "$rootfs" apt update
# chroot "$rootfs" apt install -y --no-install-recommends coreutils dpkg apt # bootstrap apt with itself
# chroot "$rootfs" apt install -y ocaml
# chroot "$rootfs" ocaml -e 'print_endline "Hello, World!"' | grep -q "Hello, World!"
