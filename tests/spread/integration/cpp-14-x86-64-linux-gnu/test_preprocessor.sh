#!/usr/bin/env bash
# spellchecker: ignore rootfs libexec ifdef ifndef

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" ]]; then
    cross=true
elif [[ "$arch" == "x86_64" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

rootfs="$(install-slices \
    base-files_bin \
    cpp-14-x86-64-linux-gnu_cc1 \
)"

if $cross; then
    ln -s "/usr/libexec/gcc-cross/x86_64-linux-gnu/14/cc1" "${rootfs}/usr/bin/cc1"
else
    ln -s "/usr/libexec/gcc/x86_64-linux-gnu/14/cc1" "${rootfs}/usr/bin/cc1"
fi

cp question.c "${rootfs}/question.c"
mkdir -p "${rootfs}/usr/include/everything"
cp answer.h "${rootfs}/usr/include/everything/"

if $cross; then
    # TODO: We do not have libc6-dev for cross /usr/lib64/ld-linux-x86-64
    :
else
    chroot "${rootfs}" cc1 -E question.c > "${rootfs}/question.i" 2>/dev/null
    cat "${rootfs}/question.i" | grep -q 'return 42;'

    # now remove answer.h and check that ANSWER is not defined
    echo "" > "${rootfs}/usr/include/everything/answer.h"
    chroot "${rootfs}" cc1 -E question.c > "${rootfs}/question.i" 2>/dev/null
    cat "${rootfs}/question.i" | grep -q 'return 1;'
fi
