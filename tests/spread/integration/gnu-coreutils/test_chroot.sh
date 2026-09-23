#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchroot gnuecho

rootfs="$(install-slices gnu-coreutils_chroot gnu-coreutils_echo)"
chroot "$rootfs" /usr/sbin/gnuchroot --version
test "$(chroot "$rootfs" /usr/sbin/gnuchroot / gnuecho "Hello, World!")" = "Hello, World!"
