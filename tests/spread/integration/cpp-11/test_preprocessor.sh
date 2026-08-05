#!/usr/bin/env bash
# spellchecker: ignore rootfs libexec ifdef ifndef
set -eu

rootfs="$(install-slices \
    base-files_bin \
    cpp-11_cc1 \
)"

triplet="$(cd "${rootfs}/usr/lib/gcc" && echo *)"

ln -s "/usr/lib/gcc/${triplet}/11/cc1" "${rootfs}/usr/bin/cc1"

cp question.c "${rootfs}/question.c"

# no answer, therefore default answer
chroot "${rootfs}" cc1 -E question.c > "${rootfs}/question.i" 2>/dev/null
cat "${rootfs}/question.i" | grep -q 'return 1;'

# specify ANSWER
chroot "${rootfs}" cc1 -DANSWER=42 -E question.c > "${rootfs}/question.i" 2>/dev/null
cat "${rootfs}/question.i" | grep -q 'return 42;'
