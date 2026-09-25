#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutouch

rootfs="$(install-slices gnu-coreutils_touch)"
chroot "$rootfs" gnutouch --version
chroot "$rootfs" gnutouch test_file
test -e "$rootfs/test_file"
chroot "$rootfs" gnutouch -d @0 test_file
test "$(stat -c '%Y' "$rootfs/test_file")" = "0"
