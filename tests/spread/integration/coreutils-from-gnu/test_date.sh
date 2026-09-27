#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_date)"
chroot "$rootfs" date --version
chroot "$rootfs" date
test "$(chroot "$rootfs" date -u -d @0 +%Y-%m-%d)" = "1970-01-01"
