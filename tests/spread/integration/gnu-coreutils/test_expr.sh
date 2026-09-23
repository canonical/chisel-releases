#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuexpr

rootfs="$(install-slices gnu-coreutils_expr)"
chroot "$rootfs" gnuexpr --version
test "$(chroot "$rootfs" gnuexpr 6 \* 7)" = "42"
test "$(chroot "$rootfs" gnuexpr length "hello")" = "5"
