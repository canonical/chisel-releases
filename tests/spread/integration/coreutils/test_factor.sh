#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_factor)"
chroot "$rootfs" factor --version
test "$(chroot "$rootfs" factor 42)" = "42: 2 3 7"
# NOTE: past 2^64, so this one goes through libgmp
test "$(chroot "$rootfs" factor 18446744073709551617)" = \
    "18446744073709551617: 274177 67280421310721"
