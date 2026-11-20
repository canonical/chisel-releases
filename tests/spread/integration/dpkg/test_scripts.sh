#!/bin/bash
#spellchecker: ignore rootfs dpkg maintscript

# the aggregate brings every dpkg script and the library they source
rootfs="$(install-slices dpkg_scripts)"

chroot "$rootfs" dpkg-maintscript-helper --help | grep -q "^Usage: dpkg-maintscript-helper"
test -x "$rootfs/usr/libexec/dpkg/dpkg-db-backup"
test -x "$rootfs/usr/libexec/dpkg/dpkg-db-keeper"
test -f "$rootfs/usr/share/dpkg/sh/dpkg-error.sh"
