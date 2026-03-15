#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9_bins)"

chroot $rootfs arpaname 123.145.167.189 | grep 189.167.145.123.IN-ADDR.ARPA
chroot $rootfs arpaname 127.0.0.1 | grep 1.0.0.127.IN-ADDR.ARPA
chroot $rootfs arpaname 8.8.8.8 | grep 8.8.8.8.IN-ADDR.ARPA