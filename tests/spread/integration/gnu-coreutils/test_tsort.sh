#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnutsort

rootfs="$(install-slices gnu-coreutils_tsort)"
chroot "$rootfs" gnutsort --version
printf "a b\nb c\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnutsort test_file)" = $'a\nb\nc'
