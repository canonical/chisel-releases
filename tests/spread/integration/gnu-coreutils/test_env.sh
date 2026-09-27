#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuenv

rootfs="$(install-slices gnu-coreutils_env)"
chroot "$rootfs" gnuenv --version
test "$(chroot "$rootfs" gnuenv -i FOO=bar gnuenv)" = "FOO=bar"
