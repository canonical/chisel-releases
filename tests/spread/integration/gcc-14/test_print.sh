#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs libgcc libexec libc multiarch

arch=$(uname -m)-linux-gnu
rootfs="$(install-slices gcc-14-"${arch//_/-/}"_gcc-14)"
ln -s "${arch}-gcc-14" "${rootfs}/usr/bin/gcc"

test "$(chroot "${rootfs}" gcc -print-search-dirs | head -n 1)" = "install: /usr/lib/gcc/${arch}/14/"
chroot "${rootfs}" gcc -print-search-dirs | head -n 2 | tail -n 1 | grep -q "/usr/libexec/gcc/${arch}/14/"
test "$(chroot "${rootfs}" gcc -print-libgcc-file-name)" = "libgcc.a"
chroot "${rootfs}" gcc -print-file-name=libc.so.6 | grep -q "libc.so.6"


# create a fake program called 'foo' in libexec dir to test -print-prog-name
touch "${rootfs}/usr/libexec/gcc/${arch}/14/foo"
chmod +x "${rootfs}/usr/libexec/gcc/${arch}/14/foo"

chroot "${rootfs}" gcc -print-prog-name=foo
test "$(chroot "${rootfs}" gcc -print-prog-name=foo)" = "/usr/libexec/gcc/${arch}/14/foo"

# we're not configured for multiple architectures
test "$(chroot "${rootfs}" gcc -print-multiarch)" = "${arch}"
test "$(chroot "${rootfs}" gcc -print-multi-directory)" = "."
test "$(chroot "${rootfs}" gcc -print-multi-lib)" = ".;"
test "$(chroot "${rootfs}" gcc -print-multi-os-directory)" = "../lib"

# we do not have the sysroot set
test -z "$(chroot "${rootfs}" gcc -print-sysroot)"
(chroot "${rootfs}" gcc -print-sysroot-headers-suffix 2>&1 || true) | grep -q "not configured with sysroot"










# chroot "${rootfs}" gcc -print-libgcc-file-name