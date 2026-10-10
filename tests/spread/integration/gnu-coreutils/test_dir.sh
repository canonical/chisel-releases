#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudir

rootfs="$(install-slices gnu-coreutils_dir)"
chroot "$rootfs" gnudir --version
chroot "$rootfs" gnudir
mkdir "$rootfs/test_dir"
echo "Hello, World!" > "$rootfs/test_dir/test_file"
test "$(chroot "$rootfs" gnudir test_dir)" = "test_file"
