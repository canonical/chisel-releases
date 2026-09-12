#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_uniq)"
chroot "$rootfs" uniq --version
printf "a\na\nb\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" uniq test_file)" = $'a\nb'
test "$(chroot "$rootfs" uniq -c test_file)" = $'      2 a\n      1 b'
