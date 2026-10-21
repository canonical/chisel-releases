#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_pwd)"
chroot "$rootfs" pwd --version
test "$(chroot "$rootfs" pwd)" = "/"
test "$(chroot "$rootfs" pwd -P)" = "/"
