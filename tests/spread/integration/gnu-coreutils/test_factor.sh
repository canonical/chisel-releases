#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnufactor

rootfs="$(install-slices gnu-coreutils_factor)"
chroot "$rootfs" gnufactor --version
test "$(chroot "$rootfs" gnufactor 42)" = "42: 2 3 7"
# NOTE: past 2^64, so this one goes through libgmp
test "$(chroot "$rootfs" gnufactor 18446744073709551617)" = \
    "18446744073709551617: 274177 67280421310721"
