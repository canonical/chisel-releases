#!/usr/bin/env bash
# spellchecker: ignore rootfs libgcc libexec libc multiarch

arch=$(uname -m)
case "$arch" in
    x86_64)   triplet="x86_64-linux-gnu"; gcc_dir="gcc" ;;
    aarch64)  triplet="aarch64-linux-gnu"; gcc_dir="gcc" ;;
    ppc64le)  triplet="powerpc64le-linux-gnu"; gcc_dir="gcc" ;;
    s390x)    triplet="s390x-linux-gnu"; gcc_dir="gcc" ;;
    *)        echo "Unsupported architecture: $arch"; exit 1 ;;
esac

rootfs="$(install-slices gcc-11_gcc-11)"
ln -s "${triplet}-gcc-11" "${rootfs}/usr/bin/gcc"

test "$(chroot "${rootfs}" gcc -print-search-dirs | head -n 1)" = "install: /usr/lib/$gcc_dir/$triplet/11/"
chroot "${rootfs}" gcc -print-search-dirs | head -n 2 | tail -n 1 | grep -q "/usr/lib/$gcc_dir/$triplet/11/"

chroot "${rootfs}" gcc -print-libgcc-file-name | grep -q "libgcc.a"
chroot "${rootfs}" gcc -print-file-name=libc.so.6 | grep -q "libc.so.6"

# create a fake program called 'foo' in lib/gcc dir to test -print-prog-name
touch "${rootfs}/usr/lib/$gcc_dir/$triplet/11/foo"
chmod +x "${rootfs}/usr/lib/$gcc_dir/$triplet/11/foo"

test "$(chroot "${rootfs}" gcc -print-prog-name=foo)" = "/usr/lib/$gcc_dir/$triplet/11/foo"

test "$(chroot "${rootfs}" gcc -print-multiarch)" = "$triplet"
test "$(chroot "${rootfs}" gcc -print-multi-directory)" = "."
chroot "${rootfs}" gcc -print-multi-lib
test "$(chroot "${rootfs}" gcc -print-multi-os-directory)" = "../lib"

test "$(chroot "${rootfs}" gcc -print-sysroot)" = ""
(chroot "${rootfs}" gcc -print-sysroot-headers-suffix 2>&1 || true) | grep -q "not configured with sysroot"
