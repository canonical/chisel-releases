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

rootfs="$(install-slices --arch "${chisel_arch}" \
golang_cgo-support \
ca-certificates_data \  # for go get ...
)"

find ${rootfs}/usr/share/go-1.22 -depth \( \
\( -path '*test*' ! -path '*src/testing*' ! -path '*src/internal/test*' \) -o \
\( -path '*/testing/*' -name '*_test.go' \) \
\) -exec rm -rf {} +

mkdir "${rootfs}/proc"
mount --bind /proc "${rootfs}/proc"

mkdir "${rootfs}/dev"
mount --bind /dev "${rootfs}/dev"

mkdir -p "${rootfs}/tmp"

mkdir "${rootfs}/app"
cp -r hello "${rootfs}/"

chroot "${rootfs}/" go version
chroot "${rootfs}/" go run /hello/cmd/hello/main.go | grep "Hello, World!"

chroot "${rootfs}/" gofmt /hello/cmd/hello/main.go > /dev/null

chroot "${rootfs}/" go -C /hello test

git clone https://github.com/canonical/chisel.git "${rootfs}/chisel"
pushd "${rootfs}/chisel" && git checkout v1.1.0 && popd
cp /etc/resolv.conf "${rootfs}/etc/resolv.conf"

chroot "${rootfs}/" go -C chisel build ./cmd/chisel
chroot "${rootfs}/" ./chisel/chisel 2>&1 > /dev/null

export CGO_ENABLED=1
chroot "${rootfs}/" go run /hello/cmd/hello_cgo/main_cgo.go | grep "Hello from C!"

umount "${rootfs}/proc"
umount "${rootfs}/dev"
rm -rf "${rootfs}/proc"
rm -rf "${rootfs}/dev"
