#!/usr/bin/env bash
# spellchecker: ignore rootfs routel Eiqx Prefsrc

rootfs="$(install-slices iproute2_routel)"

chroot "$rootfs" routel --help 2>&1 \
    | grep -iq "usage: /usr/bin/routel"

# check we get the expected column headers
chroot "$rootfs" routel 2>&1 | head -n1 | \
    grep -Eiqx "\s*Dst\s+Gateway\s+Prefsrc\s+Protocol\s+Scope\s+Dev\s+Table\s*"
