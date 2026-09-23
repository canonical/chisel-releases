#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnulink

rootfs="$(install-slices gnu-coreutils_link)"
chroot "$rootfs" gnulink --version
touch "$rootfs/test_file"
chroot "$rootfs" gnulink test_file test_file_link
echo "Hello, World!" > "$rootfs/test_file"
test "$(cat "$rootfs/test_file_link")" = "Hello, World!"
