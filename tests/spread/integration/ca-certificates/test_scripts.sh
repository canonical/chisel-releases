#!/bin/bash
#spellchecker: ignore rootfs

rootfs=$(install-slices ca-certificates_data-with-certs ca-certificates_scripts)
test -f "$rootfs/etc/ca-certificates.conf"

# mock /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

chroot "$rootfs" /usr/sbin/update-ca-certificates
test "$(find "$rootfs/etc/ssl/certs" -maxdepth 1 -type f ! -name 'ca-certificates.crt' | wc -l)" -eq 0
