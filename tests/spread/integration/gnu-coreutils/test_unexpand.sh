#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuunexpand

rootfs="$(install-slices gnu-coreutils_unexpand)"
chroot "$rootfs" gnuunexpand --version
printf "a   b\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnuunexpand -t 4 test_file)" = $'a\tb'
