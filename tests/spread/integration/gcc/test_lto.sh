rootfs="$(install-slices gcc_gcc libc6-dev_libs)"

cp testfiles/hello.c "$rootfs/hello.c"

chroot "$rootfs" gcc -flto -o hello hello.c
chroot "$rootfs" ./hello | grep -Fq "Hello from C!"

rm "$rootfs/hello"
chroot "$rootfs" cc -flto -o hello hello.c
chroot "$rootfs" ./hello | grep -Fq "Hello from C!"
