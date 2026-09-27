#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnushuf

rootfs="$(install-slices gnu-coreutils_shuf)"
chroot "$rootfs" gnushuf --version
test "$(chroot "$rootfs" gnushuf -e foo)" = "foo"
test "$(chroot "$rootfs" gnushuf -i 1-5 | sort -n | tr '\n' '-')" = "1-2-3-4-5-"
