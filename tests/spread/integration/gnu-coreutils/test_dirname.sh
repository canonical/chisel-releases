#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnudirname

rootfs="$(install-slices gnu-coreutils_dirname)"
chroot "$rootfs" gnudirname --version
test "$(chroot "$rootfs" gnudirname /foo/bar/baz.txt)" = "/foo/bar"
test "$(chroot "$rootfs" gnudirname /foo/bar/)" = "/foo"
