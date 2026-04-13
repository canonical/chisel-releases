#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices apparmor_scripts)"

chroot "$rootfs" /usr/sbin/aa-remove-unknown --help | grep -q "usage: /usr/sbin/aa-remove-unknown"
