#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_install)"
chroot "$rootfs" install --version
touch "$rootfs/test_file"
chroot "$rootfs" install -D -m 0750 test_file /tmp/test_file
test -f "$rootfs/tmp/test_file"
test "$(stat -c '%a' "$rootfs/tmp/test_file")" = "750"
