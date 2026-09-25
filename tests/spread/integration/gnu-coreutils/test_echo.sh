#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuecho

rootfs="$(install-slices gnu-coreutils_echo)"
chroot "$rootfs" gnuecho --version
test "$(chroot "$rootfs" gnuecho "Hello, World!")" = "Hello, World!"
test "$(chroot "$rootfs" gnuecho -n "foo")" = "foo"
