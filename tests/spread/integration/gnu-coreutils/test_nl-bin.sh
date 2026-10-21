#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnunl

rootfs="$(install-slices gnu-coreutils_nl-bin)"
chroot "$rootfs" gnunl --version
printf "foo\nbar\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnunl test_file)" = $'     1\tfoo\n     2\tbar'
