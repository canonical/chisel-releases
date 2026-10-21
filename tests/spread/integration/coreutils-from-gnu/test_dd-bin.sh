#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_dd-bin)"
chroot "$rootfs" dd --version
echo "Hello, World!" > "$rootfs/test_file"
chroot "$rootfs" dd if=test_file of=test_file_copy
test "$(cat "$rootfs/test_file_copy")" = "Hello, World!"
