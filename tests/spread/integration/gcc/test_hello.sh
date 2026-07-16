rootfs="$(install-slices gcc_gcc libc6-dev_libs)"

arch=$(uname -m)
arch="${arch//_/-}"
arch_triplet="${arch}-linux-gnu"

cp ../gcc-15-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"

rm "${rootfs}/hello"
chroot "${rootfs}" cc -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
