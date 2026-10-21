#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_dir)"
chroot "$rootfs" dir --version
chroot "$rootfs" dir
mkdir "$rootfs/test_dir"
echo "Hello, World!" > "$rootfs/test_dir/test_file"
test "$(chroot "$rootfs" dir test_dir)" = "test_file"
