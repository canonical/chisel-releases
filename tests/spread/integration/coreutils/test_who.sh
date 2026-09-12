#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_who)"
chroot "$rootfs" who --version
chroot "$rootfs" who -q | grep -q "^# users=0$"
