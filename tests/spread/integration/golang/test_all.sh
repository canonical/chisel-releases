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
  ca-certificates_data \  # for `go get` to work properly
)"

find ${rootfs} -depth \( \
    -name '*_test.go' -o \
    \( -type d -name 'testdata' \) -o \
    \( -type d -path '*/go-1.26/test' \) -o \
    \( -type d -path '*/src/internal/testenv' \) -o \
    \( -type d -path '*/src/internal/testpty' \) -o \
    \( -type d -path '*/src/internal/testhash' \) -o \
    \( -type d -path '*/src/internal/cgrouptest' \) -o \
    \( -type d -path '*/src/internal/obscuretestdata' \) -o \
    \( -type d -path '*/src/internal/coverage/test' \) -o \
    \( -type d -path '*/src/internal/runtime/startlinetest' \) -o \
    \( -type d -path '*/src/internal/runtime/wasitest' \) -o \
    \( -type d -path '*/src/internal/trace/internal/testgen' \) -o \
    \( -type d -path '*/src/internal/trace/testtrace' \) -o \
    \( -type d -path '*/src/net/internal/cgotest' \) -o \
    \( -type d -path '*/src/net/internal/socktest' \) -o \
    \( -type d -path '*/src/os/exec/internal/fdtest' \) -o \
    \( -type d -path '*/src/net/http/internal/testcert' \) -o \
    \( -type d -path '*/src/crypto/internal/cryptotest' \) -o \
    \( -type d -path '*/src/crypto/internal/fips140/check/checktest' \) -o \
    \( -type d -path '*/src/crypto/internal/fips140test' \) -o \
    \( -type d -path '*/src/crypto/mlkem/mlkemtest' \) -o \
    \( -type d -path '*/src/embed/internal/embedtest' \) -o \
    \( -type d -path '*/src/vendor/golang.org/x/net/nettest' \) \
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
git -C "$rootfs/chisel" checkout v1.2.0
cp /etc/resolv.conf "${rootfs}/etc/resolv.conf"

chroot "${rootfs}/" go -C chisel build ./cmd/chisel
chroot "${rootfs}/" ./chisel/chisel 2>&1 > /dev/null


export CGO_ENABLED=1
chroot "${rootfs}/" go run /hello/cmd/hello_cgo/main_cgo.go | grep "Hello from C!"

umount "${rootfs}/proc"
umount "${rootfs}/dev"
rm -rf "${rootfs}/proc"
rm -rf "${rootfs}/dev"
