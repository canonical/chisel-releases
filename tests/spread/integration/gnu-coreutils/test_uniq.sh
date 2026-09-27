#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuuniq

rootfs="$(install-slices gnu-coreutils_uniq)"
chroot "$rootfs" gnuuniq --version
printf "a\na\nb\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnuuniq test_file)" = $'a\nb'
test "$(chroot "$rootfs" gnuuniq -c test_file)" = $'      2 a\n      1 b'
