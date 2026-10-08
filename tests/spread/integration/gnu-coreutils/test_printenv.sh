#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuprintenv

rootfs="$(install-slices gnu-coreutils_printenv)"
chroot "$rootfs" gnuprintenv --version
test "$(env FOO=bar chroot "$rootfs" gnuprintenv FOO)" = "bar"
