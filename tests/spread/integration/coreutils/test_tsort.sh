#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_tsort)"
chroot "$rootfs" tsort --version
printf "a b\nb c\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" tsort test_file)" = $'a\nb\nc'
