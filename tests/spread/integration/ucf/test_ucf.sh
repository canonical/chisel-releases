#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ucf_ucf)"

chroot "$rootfs" ucf --help 2>&1 | grep -iq "usage: ucf"
