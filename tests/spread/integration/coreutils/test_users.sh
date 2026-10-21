#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_users)"
chroot "$rootfs" users --version
test -z "$(chroot "$rootfs" users)"
