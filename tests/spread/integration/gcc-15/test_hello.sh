rootfs="$(install-slices gcc-15_gcc-15 libc6-dev_libs)"

arch=$(uname -m)
arch="${arch//_/-}"
[ "${arch}" = "ppc64le" ] && arch="powerpc64le"
arch_triplet="${arch}-linux-gnu"

cp ../gcc-15-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc-15 -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
