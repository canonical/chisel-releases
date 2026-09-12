#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_cp-bin)"
chroot "$rootfs" cp --version
echo "Hello, World!" > "$rootfs/test_file"
chroot "$rootfs" cp test_file test_file_copy
test "$(cat "$rootfs/test_file_copy")" = "Hello, World!"
mkdir -p "$rootfs/test_dir"
touch "$rootfs/test_dir/test_file"
chroot "$rootfs" cp -r test_dir test_dir_copy
test -f "$rootfs/test_dir_copy/test_file"
