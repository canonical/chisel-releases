#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices base-passwd_data coreutils_chown)"
chroot "$rootfs" chown --version
touch "$rootfs/test_file"
test "$(stat -c '%U:%G' "$rootfs/test_file")" = "root:root"
chroot "$rootfs" chown nobody:nogroup test_file
test "$(stat -c '%U:%G' "$rootfs/test_file")" = "nobody:nogroup"
