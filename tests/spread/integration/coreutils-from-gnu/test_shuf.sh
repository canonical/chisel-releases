#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_shuf)"
chroot "$rootfs" shuf --version
test "$(chroot "$rootfs" shuf -e foo)" = "foo"
test "$(chroot "$rootfs" shuf -i 1-5 | sort -n | tr '\n' '-')" = "1-2-3-4-5-"
