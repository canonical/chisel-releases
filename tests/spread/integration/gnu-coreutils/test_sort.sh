#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusort

rootfs="$(install-slices gnu-coreutils_sort)"
chroot "$rootfs" gnusort --version
printf "banana\napple\ncherry\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnusort test_file | tr '\n' '-')" = "apple-banana-cherry-"
test "$(chroot "$rootfs" gnusort -r test_file | tr '\n' '-')" = "cherry-banana-apple-"
