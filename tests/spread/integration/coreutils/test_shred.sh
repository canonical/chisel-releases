#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_shred)"
chroot "$rootfs" shred --version
printf "secret" > "$rootfs/test_file"
chroot "$rootfs" shred -n 1 -z --exact test_file
test "$(od -A n -t x1 "$rootfs/test_file" | tr -d ' \n')" = "000000000000"
chroot "$rootfs" shred -u test_file
test ! -e "$rootfs/test_file"
