#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnupwd

rootfs="$(install-slices gnu-coreutils_pwd)"
chroot "$rootfs" gnupwd --version
test "$(chroot "$rootfs" gnupwd)" = "/"
test "$(chroot "$rootfs" gnupwd -P)" = "/"
