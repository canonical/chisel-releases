rootfs="$(install-slices gcc-14_gcc-14 libc6-dev_libs)"

arch=$(uname -m)
arch="${arch//_/-}"
[ "${arch}" = "ppc64le" ] && arch="powerpc64le"
arch_triplet="${arch}-linux-gnu"

cp ../gcc-14-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc-14 -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
