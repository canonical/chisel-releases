#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_fmt)"
chroot "$rootfs" fmt --version
echo "hello world" > "$rootfs/test_file"
test "$(chroot "$rootfs" fmt -w 5 test_file)" = $'hello\nworld'
