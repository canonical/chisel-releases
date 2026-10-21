#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucat

rootfs="$(install-slices gnu-coreutils_cat)"
chroot "$rootfs" gnucat --version
echo "Hello, World!" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnucat test_file)" = "Hello, World!"
test "$(chroot "$rootfs" gnucat -n test_file)" = $'     1\tHello, World!'
