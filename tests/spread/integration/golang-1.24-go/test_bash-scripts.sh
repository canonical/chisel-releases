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

rootfs=$(install-slices --arch "${chisel_arch}" \
  golang-1.22-src_bash-scripts \
  golang-1.22-go_minimal \
)

cleanup() {
  umount -l "${rootfs}"/dev
  umount -l "${rootfs}"/proc
}
trap cleanup EXIT

mkdir "${rootfs}/proc"
mount --bind /proc "${rootfs}/proc"
mkdir "${rootfs}/dev"
mount --bind /dev "${rootfs}/dev"

ln -s ../lib/go-1.24/bin/go "${rootfs}/usr/bin/go"

GO_ROOT_SRC="$(chroot "${rootfs}" go env GOROOT)/src"
GOROOT="$(chroot "${rootfs}" go env GOROOT)"

for script in ${rootfs}/usr/share/go-1.24/src/*.bash; do
  chroot "${rootfs}" bash -c "cd $GO_ROOT_SRC && GOROOT_BOOTSTRAP=$GOROOT /usr/share/go-1.24/src/$(basename "${script}")"
done
