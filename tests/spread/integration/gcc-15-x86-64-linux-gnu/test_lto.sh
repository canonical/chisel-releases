slices=(
  binutils-x86-64-linux-gnu_assembler
  binutils-x86-64-linux-gnu_cross-libs
  binutils-x86-64-linux-gnu_linker
  cpp-15-x86-64-linux-gnu_cc1
  gcc-15-x86-64-linux-gnu_gcc-15
)
rootfs="$(install-slices "${slices[@]}")"

ln -s x86_64-linux-gnu-as "$rootfs/usr/bin/as"
ln -s x86_64-linux-gnu-gcc-15 "$rootfs/usr/bin/gcc"
ln -s x86_64-linux-gnu-ld "$rootfs/usr/bin/ld"
cp testfiles/lto.c "$rootfs/lto.c"

chroot "$rootfs" gcc -flto -nostdlib -Wl,-e,lto_entry /lto.c -o /lto
test -x "$rootfs/lto"
