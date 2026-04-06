#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ucf_ucf)"

chroot "$rootfs" ucf --help | grep -iq "usage: ucf"
