#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnufold

rootfs="$(install-slices gnu-coreutils_fold)"
chroot "$rootfs" gnufold --version
echo "abcdefghij" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnufold -w 5 test_file)" = $'abcde\nfghij'
