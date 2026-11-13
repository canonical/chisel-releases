#!/bin/bash
#spellchecker: ignore rootfs

rootfs=$(install-slices ca-certificates_data-with-certs ca-certificates_scripts)
test -f "$rootfs/etc/ca-certificates.conf"

# mock /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

chroot "$rootfs" /usr/sbin/update-ca-certificates
# Every certificate listed in ca-certificates.conf must end up in the bundle.
test "$(grep -c 'BEGIN CERTIFICATE' "$rootfs/etc/ssl/certs/ca-certificates.crt")" -eq "$(grep -c . "$rootfs/etc/ca-certificates.conf")"
test "$(find "$rootfs/etc/ssl/certs" -maxdepth 1 -type f ! -name 'ca-certificates.crt' | wc -l)" -eq 0
