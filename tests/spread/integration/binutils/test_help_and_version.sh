set -eu

rootfs="$(install-slices binutils_assembler binutils_linker binutils_archiver)"

chroot "${rootfs}/" as --version | grep "GNU assembler"
chroot "${rootfs}/" ld --version | grep "GNU ld"
chroot "${rootfs}/" ld.bfd --version | grep "GNU ld"
chroot "${rootfs}/" ar --version | grep "GNU ar"
