#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_sleep)"
chroot "$rootfs" sleep --version
chroot "$rootfs" sleep 0.1
