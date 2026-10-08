slices=(
  binutils-powerpc64le-linux-gnu_assembler
  binutils-powerpc64le-linux-gnu_cross-libs
  binutils-powerpc64le-linux-gnu_linker
  cpp-15-powerpc64le-linux-gnu_cc1
  gcc-15-powerpc64le-linux-gnu_gcc-15
)
rootfs="$(install-slices "${slices[@]}")"

ln -s powerpc64le-linux-gnu-as "$rootfs/usr/bin/as"
ln -s powerpc64le-linux-gnu-gcc-15 "$rootfs/usr/bin/gcc"
ln -s powerpc64le-linux-gnu-ld "$rootfs/usr/bin/ld"
cp testfiles/lto.c "$rootfs/lto.c"

chroot "$rootfs" gcc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto
test -x "$rootfs/lto"
