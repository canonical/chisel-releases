#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_yes)"
chroot "$rootfs" yes --version
test "$(chroot "$rootfs" yes hello | head -n 3)" = $'hello\nhello\nhello'
