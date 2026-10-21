#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuseq

rootfs="$(install-slices gnu-coreutils_seq)"
chroot "$rootfs" gnuseq --version
test "$(chroot "$rootfs" gnuseq 3 | tr '\n' '-')" = "1-2-3-"
test "$(chroot "$rootfs" gnuseq 3 -1 1 | tr '\n' '-')" = "3-2-1-"
