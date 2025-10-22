#!/usr/bin/env bash
# spellchecker: ignore rootfs libexec

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

if $cross; then
    rootfs="$(install-slices \
        base-files_bin \
        cpp-14-x86-64-linux-gnu_cc1 \
    )"
    echo here1
    ln -s "/usr/libexec/gcc-cross/x86_64-linux-gnu/14/cc1" "${rootfs}/usr/bin/cc1"
else
    rootfs="$(install-slices \
        base-files_bin \
        cpp-14-x86-64-linux-gnu_cc1 \
    )"
    echo here2
    ln -s "/usr/libexec/gcc/x86_64-linux-gnu/14/cc1" "${rootfs}/usr/bin/cc1"
fi

if $cross; then
    # TODO: We do not have libc6-dev for cross /usr/lib64/ld-linux-x86-64
    :
else
    (chroot "${rootfs}" cc1 --help || true) | grep -q "The following options are language-independent:"
fi

