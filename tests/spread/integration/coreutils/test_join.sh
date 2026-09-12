#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_join)"
chroot "$rootfs" join --version
printf "1,apple\n2,banana\n" > "$rootfs/file1"
printf "1,orange\n2,grape\n" > "$rootfs/file2"
test "$(chroot "$rootfs" join -t , file1 file2)" = $'1,apple,orange\n2,banana,grape'
