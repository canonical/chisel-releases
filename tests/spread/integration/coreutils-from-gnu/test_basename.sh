#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_basename)"
chroot "$rootfs" basename --version
test "$(chroot "$rootfs" basename /foo/bar/test_file)" = "test_file"
test "$(chroot "$rootfs" basename /foo/bar/test_file.txt .txt)" = "test_file"
