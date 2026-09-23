#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_du-bin)"
chroot "$rootfs" du --version
mkdir -p "$rootfs/test_dir"
head -c 2048 /dev/zero > "$rootfs/test_dir/test_file"
test "$(chroot "$rootfs" du -b test_dir/test_file)" = $'2048\ttest_dir/test_file'
chroot "$rootfs" du -s test_dir | grep -qE $'^[0-9]+\ttest_dir$'
