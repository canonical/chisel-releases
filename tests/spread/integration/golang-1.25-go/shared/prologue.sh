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

rootfs="$(install-slices --arch "${chisel_arch}" golang-1.25-go_${SLICE} golang-1.25-go_minimal)"

# we need dev/sys mounted for some of them
mkdir "${rootfs}"/dev
mkdir "${rootfs}/proc"

mount --bind /dev "${rootfs}"/dev
mount --bind /proc "${rootfs}/proc"

mkdir -p "${rootfs}/tmp"

echo -n "${rootfs}"
