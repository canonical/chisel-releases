#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudu

rootfs="$(install-slices gnu-coreutils_du-bin)"
chroot "$rootfs" gnudu --version
mkdir -p "$rootfs/test_dir"
head -c 2048 /dev/zero > "$rootfs/test_dir/test_file"
test "$(chroot "$rootfs" gnudu -b test_dir/test_file)" = $'2048\ttest_dir/test_file'
chroot "$rootfs" gnudu -s test_dir | grep -qE $'^[0-9]+\ttest_dir$'
