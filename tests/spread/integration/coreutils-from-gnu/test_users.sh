#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_users)"
chroot "$rootfs" users --version
test -z "$(chroot "$rootfs" users)"
