#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuid

rootfs="$(install-slices gnu-coreutils_id-bin)"
chroot "$rootfs" gnuid --version
chroot "$rootfs" gnuid
test "$(chroot "$rootfs" gnuid -u)" = "0"
test "$(chroot "$rootfs" gnuid -g)" = "0"
