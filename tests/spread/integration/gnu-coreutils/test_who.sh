#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuwho

rootfs="$(install-slices gnu-coreutils_who)"
chroot "$rootfs" gnuwho --version
chroot "$rootfs" gnuwho -q | grep -q "^# users=0$"
