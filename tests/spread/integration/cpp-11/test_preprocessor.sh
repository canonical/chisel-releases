#!/usr/bin/env bash
# spellchecker: ignore rootfs libexec ifdef ifndef
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

cp question.c "${rootfs}/question.c"

# no answer, therefore default answer
chroot "${rootfs}" cc1 -E question.c > "${rootfs}/question.i" 2>/dev/null
grep -q 'return 1;' "${rootfs}/question.i"

# specify ANSWER
chroot "${rootfs}" cc1 -DANSWER=42 -E question.c > "${rootfs}/question.i" 2>/dev/null
grep -q 'return 42;' "${rootfs}/question.i"
