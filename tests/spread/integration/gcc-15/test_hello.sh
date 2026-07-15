rootfs="$(install-slices gcc-15_gcc-15 libc6-dev_libs)"

cp ../gcc-15-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc-15 -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
