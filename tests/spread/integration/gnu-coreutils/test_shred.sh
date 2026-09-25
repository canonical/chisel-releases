#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnushred

rootfs="$(install-slices gnu-coreutils_shred)"
chroot "$rootfs" gnushred --version
printf "secret" > "$rootfs/test_file"
chroot "$rootfs" gnushred -n 1 -z --exact test_file
test "$(od -A n -t x1 "$rootfs/test_file" | tr -d ' \n')" = "000000000000"
chroot "$rootfs" gnushred -u test_file
test ! -e "$rootfs/test_file"
