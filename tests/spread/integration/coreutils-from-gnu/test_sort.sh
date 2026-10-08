#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_sort)"
chroot "$rootfs" sort --version
printf "banana\napple\ncherry\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" sort test_file | tr '\n' '-')" = "apple-banana-cherry-"
test "$(chroot "$rootfs" sort -r test_file | tr '\n' '-')" = "cherry-banana-apple-"
