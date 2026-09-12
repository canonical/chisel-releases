#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_echo)"
chroot "$rootfs" echo --version
test "$(chroot "$rootfs" echo "Hello, World!")" = "Hello, World!"
test "$(chroot "$rootfs" echo -n "foo")" = "foo"
