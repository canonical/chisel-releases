#!/usr/bin/env bash
# spellchecker: ignore rootfs libexec
set -eu

rootfs="$(install-slices \
    base-files_bin \
    cpp-11_cc1 \
)"

triplet="$(cd "${rootfs}/usr/lib/gcc" && echo *)"

ln -s "/usr/lib/gcc/${triplet}/11/cc1" "${rootfs}/usr/bin/cc1"

(chroot "${rootfs}" cc1 --help || true) | grep -q "The following options are language-independent:"
