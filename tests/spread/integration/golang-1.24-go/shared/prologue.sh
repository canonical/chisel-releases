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

rootfs="$(install-slices --arch "${chisel_arch}" golang-1.24-go_${SLICE} golang-1.24-go_minimal)"

# we need dev/sys mounted for some of them
mkdir "${rootfs}"/dev
mkdir "${rootfs}/proc"

mount --bind /dev "${rootfs}"/dev
mount --bind /proc "${rootfs}/proc"

mkdir -p "${rootfs}/tmp"

# create symlinks as golang-go, but for 1.24
ln -s ../lib/go-1.24/bin/go "${rootfs}/usr/bin/go"
ln -s ../lib/go-1.24/bin/gofmt "${rootfs}/usr/bin/gofmt"
ln -s ../share/go-1.24 "${rootfs}/usr/lib/go"

# create symlinks as golang-src, but for 1.24
ln -s go-1.24 "${rootfs}/usr/share/go"

echo -n "${rootfs}"
