# TODO: remove the --arch and the ${arch} logic once
# canonical/chisel #256 is merged.
arch=$(uname -m)
arch="${arch//_/-}"
arch_triplet="${arch}-linux-gnu"

if [ "${arch}" = "aarch64" ]; then
chisel_arch="arm64"
elif [ "${arch}" = "x86-64" ]; then
chisel_arch="amd64"
else
echo "Unsupported architecture: ${arch}"
exit 1
fi

rootfs="$(install-slices --arch "${chisel_arch}" gcc_gcc libc6-dev_libs)"

cp ../gcc-14-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
