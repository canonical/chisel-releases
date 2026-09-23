#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_cut)"
chroot "$rootfs" cut --version
echo "foo,bar" > "$rootfs/test_file"
test "$(chroot "$rootfs" cut -d ',' -f 1 test_file)" = "foo"
test "$(chroot "$rootfs" cut -c 5- test_file)" = "bar"
