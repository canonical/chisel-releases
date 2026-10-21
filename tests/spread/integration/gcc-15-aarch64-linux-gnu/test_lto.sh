slices=(
  binutils-aarch64-linux-gnu_assembler
  binutils-aarch64-linux-gnu_cross-libs
  binutils-aarch64-linux-gnu_linker
  cpp-15-aarch64-linux-gnu_cc1
  gcc-15-aarch64-linux-gnu_gcc-15
)
rootfs="$(install-slices "${slices[@]}")"

ln -s aarch64-linux-gnu-as "$rootfs/usr/bin/as"
ln -s aarch64-linux-gnu-gcc-15 "$rootfs/usr/bin/gcc"
ln -s aarch64-linux-gnu-ld "$rootfs/usr/bin/ld"
cp testfiles/lto.c "$rootfs/lto.c"

chroot "$rootfs" gcc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto
test -x "$rootfs/lto"
