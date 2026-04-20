#!/bin/bash
#spellchecker: ignore rootfs findutils coreutils

rootfs="$(install-slices findutils_xargs)"


chroot "$rootfs" xargs --help 2>&1 | grep -iq "usage"
chroot "$rootfs" xargs --version 2>&1 | grep -iq "xargs (gnu findutils)"

rootfs_touch="$(install-slices findutils_xargs coreutils_touch)"
mkdir -p "$rootfs_touch/dev" && touch "$rootfs_touch/dev/null"

# test xargs works
mkdir -p "$rootfs_touch/tmp"
echo "/tmp/foo /tmp/bar /tmp/baz" | chroot "$rootfs_touch" xargs -n1 touch
test -f "$rootfs_touch/tmp/foo"
test -f "$rootfs_touch/tmp/bar"
test -f "$rootfs_touch/tmp/baz"
