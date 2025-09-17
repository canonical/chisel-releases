#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs resolv libc coreutils
rootfs="$(install-slices apt_apt-get-mini)"

# For DNS resolution
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

# Apt wants /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# update package lists
chroot "$rootfs" apt update
libc6_share_before=$(find "$rootfs/usr/share/doc/libc6" -type f -printf "%P\n" | sort | tr '\n' ' ')

# Reinstall apt, dpkg and coreutils
chroot "$rootfs" apt install -y --no-install-recommends coreutils dpkg apt

# we only include the copyright file initially, so there should be more files after installation
libc6_share_after=$(find "$rootfs/usr/share/doc/libc6" -type f -printf "%P\n" | sort | tr '\n' ' ')
test "$libc6_share_before" != "$libc6_share_after"
# we should now have a fully-fledged apt installation
