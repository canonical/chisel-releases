#!/bin/bash
#spellchecker: ignore rootfs resolv urllib urlopen

rootfs="$(install-slices ca-certificates_data python3.13_core)"
cp /etc/resolv.conf "$rootfs/etc/"
chroot "$rootfs" /usr/bin/python3.13 -c "import urllib.request;urllib.request.urlopen('https://example.com')"