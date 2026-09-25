#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_printenv)"
chroot "$rootfs" printenv --version
test "$(env FOO=bar chroot "$rootfs" printenv FOO)" = "bar"
