#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnugroups

rootfs="$(install-slices base-passwd_data gnu-coreutils_groups)"
chroot "$rootfs" gnugroups --version
test "$(chroot "$rootfs" gnugroups)" = "root"
test "$(chroot "$rootfs" gnugroups root)" = "root : root"
