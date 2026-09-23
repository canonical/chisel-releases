#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_touch)"
chroot "$rootfs" touch --version
chroot "$rootfs" touch test_file
test -e "$rootfs/test_file"
chroot "$rootfs" touch -d @0 test_file
test "$(stat -c '%Y' "$rootfs/test_file")" = "0"
