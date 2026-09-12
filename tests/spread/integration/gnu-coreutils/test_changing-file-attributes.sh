#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchgrp gnuchmod gnuchown gnutouch

rootfs="$(install-slices gnu-coreutils_changing-file-attributes)"
cmds=(
    gnuchgrp
    gnuchmod
    gnuchown
    gnutouch
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
