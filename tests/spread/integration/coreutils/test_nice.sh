#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_nice)"
chroot "$rootfs" nice --version
niceness="$(chroot "$rootfs" nice)"
test "$(chroot "$rootfs" nice -n 5 nice)" = "$((niceness + 5))"
