#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_select-editor)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"
mkdir -p "$rootfs/root" && touch "$rootfs/root/.selected_editor"

chroot "$rootfs" select-editor 2>&1 | grep -iq "no alternatives for editor"
