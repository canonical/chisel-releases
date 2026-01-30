
# TODO: go tool gco calls gcc though the symlink is missing in the rootfs
#       once https://github.com/canonical/chisel-releases/pull/836 is merged,
#       we can add it to the essentials and remove this workaround
arch=$(uname -m)
ln -s "$arch-linux-gnu-gcc-15" "${rootfs}/usr/bin/${arch}-linux-gnu-gcc"

chroot "${rootfs}" /usr/lib/go-1.24/bin/go tool cgo -V
cp ../golang/hello/cmd/hello_cgo/main_cgo.go "${rootfs}/main_cgo.go"
chroot "${rootfs}" /usr/lib/go-1.24/bin/go tool cgo main_cgo.go
grep -q "hello_from_c" "${rootfs}/_obj/_cgo_.o"
