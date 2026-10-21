#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_tr-bin)"
chroot "$rootfs" tr --version
test "$(echo "hello world" | chroot "$rootfs" tr '[:lower:]' '[:upper:]')" = "HELLO WORLD"
test "$(echo "hello" | chroot "$rootfs" tr -d 'l')" = "heo"
