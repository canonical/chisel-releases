#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_pr-bin)"
chroot "$rootfs" pr --version
printf "foo\nbar\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" pr -t test_file)" = $'foo\nbar'
chroot "$rootfs" pr -h "Test Title" test_file | grep -q "Test Title"
