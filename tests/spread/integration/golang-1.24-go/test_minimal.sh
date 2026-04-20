cp ../golang/hello/cmd/hello/main.go "${rootfs}/hello.go"
chroot "${rootfs}" /usr/lib/go-1.24/bin/go run /hello.go | grep "Hello, World!"
