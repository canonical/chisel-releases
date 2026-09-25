#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_seq)"
chroot "$rootfs" seq --version
test "$(chroot "$rootfs" seq 3 | tr '\n' '-')" = "1-2-3-"
test "$(chroot "$rootfs" seq 3 -1 1 | tr '\n' '-')" = "3-2-1-"
