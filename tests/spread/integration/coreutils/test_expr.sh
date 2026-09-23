#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_expr)"
chroot "$rootfs" expr --version
test "$(chroot "$rootfs" expr 6 \* 7)" = "42"
test "$(chroot "$rootfs" expr length "hello")" = "5"
