#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_cat)"
chroot "$rootfs" cat --version
echo "Hello, World!" > "$rootfs/test_file"
test "$(chroot "$rootfs" cat test_file)" = "Hello, World!"
test "$(chroot "$rootfs" cat -n test_file)" = $'     1\tHello, World!'
