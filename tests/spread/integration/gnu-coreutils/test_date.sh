#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudate

rootfs="$(install-slices gnu-coreutils_date)"
chroot "$rootfs" gnudate --version
chroot "$rootfs" gnudate
test "$(chroot "$rootfs" gnudate -u -d @0 +%Y-%m-%d)" = "1970-01-01"
