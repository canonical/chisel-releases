#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchown

rootfs="$(install-slices base-passwd_data gnu-coreutils_chown)"
chroot "$rootfs" gnuchown --version
touch "$rootfs/test_file"
test "$(stat -c '%U:%G' "$rootfs/test_file")" = "root:root"
chroot "$rootfs" gnuchown nobody:nogroup test_file
test "$(stat -c '%U:%G' "$rootfs/test_file")" = "nobody:nogroup"
