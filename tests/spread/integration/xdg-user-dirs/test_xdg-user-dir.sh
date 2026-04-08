#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices xdg-user-dirs_scripts)"

chroot "$rootfs" xdg-user-dir | grep -iqx '/root'
