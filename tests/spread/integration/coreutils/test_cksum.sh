#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_cksum)"
chroot "$rootfs" cksum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" cksum test_file)" = "3287646509 5 test_file"
test "$(chroot "$rootfs" cksum -a sha256 test_file)" = \
    "SHA256 (test_file) = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
