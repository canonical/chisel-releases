rootfs="$(install-slices golang-1.25-go_${SLICE} golang-1.25-go_minimal)"

# we need dev/sys mounted for some of them
mkdir "${rootfs}"/dev
mkdir "${rootfs}/proc"

mount --bind /dev "${rootfs}"/dev
mount --bind /proc "${rootfs}/proc"

mkdir -p "${rootfs}/tmp"

echo -n "${rootfs}"
