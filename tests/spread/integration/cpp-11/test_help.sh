#!/usr/bin/env bash
# spellchecker: ignore rootfs libexec
set -eu

arch=$(uname -m)
case "$arch" in
    x86_64)   triplet="x86_64-linux-gnu" ;;
    aarch64)  triplet="aarch64-linux-gnu" ;;
    ppc64le)  triplet="powerpc64le-linux-gnu" ;;
    s390x)    triplet="s390x-linux-gnu" ;;
    *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
esac

rootfs="$(install-slices \
    base-files_bin \
    cpp-11_cc1 \
)"

ln -s "/usr/lib/gcc/${triplet}/11/cc1" "${rootfs}/usr/bin/cc1"

(chroot "${rootfs}" cc1 --help || true) | grep -q "The following options are language-independent:"
