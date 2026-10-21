#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_chcon)"
chroot "$rootfs" chcon --version
touch "$rootfs/test_file"
# NOTE: the file carries no selinux label for a partial context to amend
chroot "$rootfs" chcon -t foo_t test_file 2>&1 | \
    grep -q "can't apply partial context to unlabeled file"
