#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuecho gnunohup

rootfs="$(install-slices gnu-coreutils_echo gnu-coreutils_nohup)"
chroot "$rootfs" gnunohup --version
test "$(chroot "$rootfs" gnunohup gnuecho "Hello, World!")" = "Hello, World!"
