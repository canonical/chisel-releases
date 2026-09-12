#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_nl-bin)"
chroot "$rootfs" nl --version
printf "foo\nbar\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" nl test_file)" = $'     1\tfoo\n     2\tbar'
