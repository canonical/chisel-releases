#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_stat)"
chroot "$rootfs" stat --version
touch "$rootfs/test_file"
chroot "$rootfs" stat test_file
test "$(chroot "$rootfs" stat -c '%s' test_file)" = "0"
