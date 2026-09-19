#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuexpand

rootfs="$(install-slices gnu-coreutils_expand)"
chroot "$rootfs" gnuexpand --version
printf "a\tb\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnuexpand -t 4 test_file)" = "a   b"
