#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudd

rootfs="$(install-slices gnu-coreutils_dd-bin)"
chroot "$rootfs" gnudd --version
echo "Hello, World!" > "$rootfs/test_file"
chroot "$rootfs" gnudd if=test_file of=test_file_copy
test "$(cat "$rootfs/test_file_copy")" = "Hello, World!"
