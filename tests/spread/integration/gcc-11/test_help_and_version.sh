#!/usr/bin/env bash
# spellchecker: ignore rootfs

arch=$(uname -m)
case "$arch" in
    x86_64)   triplet="x86_64-linux-gnu" ;;
    aarch64)  triplet="aarch64-linux-gnu" ;;
    ppc64le)  triplet="powerpc64le-linux-gnu" ;;
    s390x)    triplet="s390x-linux-gnu" ;;
    *)        echo "Unsupported architecture: $arch"; exit 1 ;;
esac

rootfs="$(install-slices gcc-11_gcc-11)"
ln -s "${triplet}-gcc-11" "${rootfs}/usr/bin/gcc"

# something like: Usage: gcc [options] file...
help=$(chroot "${rootfs}" gcc --help | head -n1)
echo "$help" | grep -q "Usage: gcc"

# something like: gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
version=$(chroot "${rootfs}" gcc --version | head -n1)
echo "$version" | grep -q "gcc"
echo "$version" | grep -q "11."
