#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuecho gnustdbuf

rootfs="$(install-slices gnu-coreutils_echo gnu-coreutils_stdbuf)"
chroot "$rootfs" gnustdbuf --version
test "$(chroot "$rootfs" gnustdbuf -oL gnuecho "Hello, World!")" = "Hello, World!"
