#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices base-passwd_data coreutils_groups)"
chroot "$rootfs" groups --version
test "$(chroot "$rootfs" groups)" = "root"
test "$(chroot "$rootfs" groups root)" = "root : root"
