#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_libs)"
test -f "$rootfs/usr/libexec/coreutils/libstdbuf.so"
head -c 4 "$rootfs/usr/libexec/coreutils/libstdbuf.so" | grep -q "ELF"
