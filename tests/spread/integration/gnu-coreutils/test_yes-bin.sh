#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuyes

rootfs="$(install-slices gnu-coreutils_yes-bin)"
chroot "$rootfs" gnuyes --version
test "$(chroot "$rootfs" gnuyes hello | head -n 3)" = $'hello\nhello\nhello'
