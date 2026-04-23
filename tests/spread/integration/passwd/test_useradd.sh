#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices passwd_useradd)"

chroot "$rootfs" useradd --help | grep -iq "usage"

chroot "$rootfs" useradd -M foo
grep -q foo "$rootfs/etc/passwd"
