#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucp

rootfs="$(install-slices gnu-coreutils_cp-bin)"
chroot "$rootfs" gnucp --version
echo "Hello, World!" > "$rootfs/test_file"
chroot "$rootfs" gnucp test_file test_file_copy
test "$(cat "$rootfs/test_file_copy")" = "Hello, World!"
mkdir -p "$rootfs/test_dir"
touch "$rootfs/test_dir/test_file"
chroot "$rootfs" gnucp -r test_dir test_dir_copy
test -f "$rootfs/test_dir_copy/test_file"
