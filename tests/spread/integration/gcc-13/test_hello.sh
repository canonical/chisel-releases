rootfs="$(install-slices gcc-13_gcc-13 libc6-dev_libs)"

arch=$(uname -m)
arch="${arch//_/-}"
[ "${arch}" = "ppc64le" ] && arch="powerpc64le"
arch_triplet="${arch}-linux-gnu"

cp ../gcc-13-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc-13 -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
