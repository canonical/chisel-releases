#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutr

rootfs="$(install-slices gnu-coreutils_tr-bin)"
chroot "$rootfs" gnutr --version
test "$(echo "hello world" | chroot "$rootfs" gnutr '[:lower:]' '[:upper:]')" = "HELLO WORLD"
test "$(echo "hello" | chroot "$rootfs" gnutr -d 'l')" = "heo"
