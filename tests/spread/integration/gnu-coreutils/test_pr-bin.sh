#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnupr

rootfs="$(install-slices gnu-coreutils_pr-bin)"
chroot "$rootfs" gnupr --version
printf "foo\nbar\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnupr -t test_file)" = $'foo\nbar'
chroot "$rootfs" gnupr -h "Test Title" test_file | grep -q "Test Title"
