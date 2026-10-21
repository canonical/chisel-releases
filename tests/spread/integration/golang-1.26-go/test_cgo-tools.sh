chroot "${rootfs}" /usr/lib/go-1.26/bin/go tool cgo -V
cp ../golang/hello/cmd/hello_cgo/main_cgo.go "${rootfs}/main_cgo.go"
chroot "${rootfs}" /usr/lib/go-1.26/bin/go tool cgo main_cgo.go
grep -Fq "hello_from_c" "${rootfs}/_cgo_2.o"
