#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_dirname)"
chroot "$rootfs" dirname --version
test "$(chroot "$rootfs" dirname /foo/bar/baz.txt)" = "/foo/bar"
test "$(chroot "$rootfs" dirname /foo/bar/)" = "/foo"
