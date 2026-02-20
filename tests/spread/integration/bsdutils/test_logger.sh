#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils rbind

rootfs="$(install-slices bsdutils_bins)"

chroot "$rootfs" /usr/bin/logger --help| grep -q "Usage:"
chroot "$rootfs" /usr/bin/logger --version| grep -q "logger"

chroot "$rootfs" /usr/bin/logger \
    --stderr "hello world" \
    --socket-errors=off 2>&1 | grep -q "hello world"
