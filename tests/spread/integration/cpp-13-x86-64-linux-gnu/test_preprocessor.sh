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
    cpp-13-x86-64-linux-gnu_cc1 \
)"

if $cross; then
    ln -s "/usr/libexec/gcc-cross/x86_64-linux-gnu/13/cc1" "${rootfs}/usr/bin/cc1"
else
    ln -s "/usr/libexec/gcc/x86_64-linux-gnu/13/cc1" "${rootfs}/usr/bin/cc1"
fi

cp question.c "${rootfs}/question.c"

# no answer, therefore default answer
chroot "${rootfs}" cc1 -E question.c > "${rootfs}/question.i" 2>/dev/null
cat "${rootfs}/question.i" | grep -q 'return 1;'

# specify ANSWER
chroot "${rootfs}" cc1 -DANSWER=42 -E question.c > "${rootfs}/question.i" 2>/dev/null
cat "${rootfs}/question.i" | grep -q 'return 42;'
