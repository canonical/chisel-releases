#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnunice

rootfs="$(install-slices gnu-coreutils_nice)"
chroot "$rootfs" gnunice --version
niceness="$(chroot "$rootfs" gnunice)"
test "$(chroot "$rootfs" gnunice -n 5 gnunice)" = "$((niceness + 5))"
