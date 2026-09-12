#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_realpath)"
chroot "$rootfs" realpath --version
mkdir -p "$rootfs/foo/bar"
touch "$rootfs/foo/bar/baz.txt"
test "$(chroot "$rootfs" realpath /foo/bar/baz.txt)" = "/foo/bar/baz.txt"
ln -s /foo/bar/baz.txt "$rootfs/foo/bar/baz_link.txt"
test "$(chroot "$rootfs" realpath /foo/bar/baz_link.txt)" = "/foo/bar/baz.txt"
