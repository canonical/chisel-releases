#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuusers

rootfs="$(install-slices gnu-coreutils_users)"
chroot "$rootfs" gnuusers --version
test -z "$(chroot "$rootfs" gnuusers)"
