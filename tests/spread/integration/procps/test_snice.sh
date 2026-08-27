#!/usr/bin/env bash
# spellchecker: ignore rootfs procps snice

rootfs="$(install-slices procps_snice)"

chroot "$rootfs" snice --version 2>&1 | grep -Fq 'snice from procps-ng'
