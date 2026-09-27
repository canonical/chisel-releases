#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_fold)"
chroot "$rootfs" fold --version
echo "abcdefghij" > "$rootfs/test_file"
test "$(chroot "$rootfs" fold -w 5 test_file)" = $'abcde\nfghij'
