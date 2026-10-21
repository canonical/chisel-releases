#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_tee)"
chroot "$rootfs" tee --version
test "$(echo "hello" | chroot "$rootfs" tee test_file)" = "hello"
test "$(cat "$rootfs/test_file")" = "hello"
echo "world" | chroot "$rootfs" tee -a test_file > /dev/null
test "$(cat "$rootfs/test_file")" = $'hello\nworld'
