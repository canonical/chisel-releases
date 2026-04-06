#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ucf_ucfq)"

chroot "$rootfs" ucfq --help | grep -iq "usage: ucfq"
