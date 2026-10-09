#!/bin/bash
#spellchecker: ignore rootfs dpkg

rootfs="$(install-slices dpkg_db-keeper)"

# without git in the rootfs the hook does nothing, and must not fail dpkg
chroot "$rootfs" /usr/libexec/dpkg/dpkg-db-keeper
