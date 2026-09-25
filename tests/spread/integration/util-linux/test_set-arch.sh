#!/bin/bash
#spellchecker: ignore rootfs setarch

rootfs="$(install-slices "util-linux_set-arch")"

chroot "$rootfs" setarch --list | grep "linux32"
