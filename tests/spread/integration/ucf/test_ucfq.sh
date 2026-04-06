#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ucf_ucfq)"

chroot "$rootfs" ucfq --help 2>&1 | grep -iq "usage: ucfq"
