chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool cgo -V
cp ../golang/hello/cmd/hello_cgo/main_cgo.go "${rootfs}/main_cgo.go"
chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool cgo main_cgo.go
grep -q "hello_from_c" "${rootfs}/_obj/_cgo_.o"
