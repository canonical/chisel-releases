slices=(
  binutils-s390x-linux-gnu_assembler
  binutils-s390x-linux-gnu_cross-libs
  binutils-s390x-linux-gnu_linker
  cpp-15-s390x-linux-gnu_cc1
  gcc-15-s390x-linux-gnu_gcc-15
)
rootfs="$(install-slices "${slices[@]}")"

ln -s s390x-linux-gnu-as "$rootfs/usr/bin/as"
ln -s s390x-linux-gnu-gcc-15 "$rootfs/usr/bin/gcc"
ln -s s390x-linux-gnu-ld "$rootfs/usr/bin/ld"
cp testfiles/lto.c "$rootfs/lto.c"

chroot "$rootfs" gcc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto
test -x "$rootfs/lto"
