#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnufmt

rootfs="$(install-slices gnu-coreutils_fmt)"
chroot "$rootfs" gnufmt --version
echo "hello world" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnufmt -w 5 test_file)" = $'hello\nworld'
