#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_id-bin)"
chroot "$rootfs" id --version
chroot "$rootfs" id
test "$(chroot "$rootfs" id -u)" = "0"
test "$(chroot "$rootfs" id -g)" = "0"
