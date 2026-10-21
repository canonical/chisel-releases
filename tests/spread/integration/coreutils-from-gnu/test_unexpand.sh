#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_unexpand)"
chroot "$rootfs" unexpand --version
printf "a   b\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" unexpand -t 4 test_file)" = $'a\tb'
