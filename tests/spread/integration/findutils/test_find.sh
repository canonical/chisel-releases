#!/bin/bash
#spellchecker: ignore rootfs findutils

rootfs="$(install-slices findutils_find)"

chroot "$rootfs" find --help 2>&1 | grep -iq "usage"
chroot "$rootfs" find --version 2>&1 | grep -iq "find (gnu findutils)"

mkdir -p $rootfs/tmp
touch $rootfs/tmp/foo
chroot "$rootfs" find /tmp -type f -print0 | grep -q "foo"
chroot "$rootfs" find / -type d -name "tmp" | grep -q "tmp"
