#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_link)"
chroot "$rootfs" link --version
touch "$rootfs/test_file"
chroot "$rootfs" link test_file test_file_link
echo "Hello, World!" > "$rootfs/test_file"
test "$(cat "$rootfs/test_file_link")" = "Hello, World!"
