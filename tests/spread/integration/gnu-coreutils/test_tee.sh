#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutee

rootfs="$(install-slices gnu-coreutils_tee)"
chroot "$rootfs" gnutee --version
test "$(echo "hello" | chroot "$rootfs" gnutee test_file)" = "hello"
test "$(cat "$rootfs/test_file")" = "hello"
echo "world" | chroot "$rootfs" gnutee -a test_file > /dev/null
test "$(cat "$rootfs/test_file")" = $'hello\nworld'
