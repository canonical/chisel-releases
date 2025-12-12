# TODO: remove the --arch and the ${arch} logic once
# canonical/chisel #256 is merged.
arch=$(uname -m)
arch="${arch//_/-}"

if [ "${arch}" = "aarch64" ]; then
chisel_arch="arm64"
elif [ "${arch}" = "x86-64" ]; then
chisel_arch="amd64"
else
echo "Unsupported architecture: ${arch}"
exit 1
fi

rootfs="$(install-slices --arch "${chisel_arch}" binutils_assembler binutils_linker binutils_archiver)"

chroot "${rootfs}/" as --version | grep "GNU assembler"
chroot "${rootfs}/" ld --version | grep "GNU ld"
chroot "${rootfs}/" ld.bfd --version | grep "GNU ld"
chroot "${rootfs}/" ar --version | grep "GNU ar"
