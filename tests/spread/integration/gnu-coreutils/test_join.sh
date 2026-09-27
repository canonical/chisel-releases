#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnujoin

rootfs="$(install-slices gnu-coreutils_join)"
chroot "$rootfs" gnujoin --version
printf "1,apple\n2,banana\n" > "$rootfs/file1"
printf "1,orange\n2,grape\n" > "$rootfs/file2"
test "$(chroot "$rootfs" gnujoin -t , file1 file2)" = $'1,apple,orange\n2,banana,grape'
