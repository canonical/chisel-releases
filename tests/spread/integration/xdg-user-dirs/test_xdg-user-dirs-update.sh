#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices xdg-user-dirs_bins)"

chroot "$rootfs" xdg-user-dirs-update --help | grep -qi "usage: xdg-user-dirs-update"

chroot "$rootfs" xdg-user-dirs-update --force --dummy-output /tmp/dummy_output --set DESKTOP /tmp/desktop
test -f "$rootfs/tmp/dummy_output"
grep -q "XDG_DESKTOP_DIR=\"/tmp/desktop\"" "$rootfs/tmp/dummy_output"
grep -q "# This file is written by xdg-user-dirs-update" "$rootfs/tmp/dummy_output"
