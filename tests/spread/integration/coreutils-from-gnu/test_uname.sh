#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_uname)"
chroot "$rootfs" uname --version
test "$(chroot "$rootfs" uname -s)" = "Linux"
test "$(chroot "$rootfs" uname -m)" = "$(uname -m)"
