source "$(dirname "$0")/helpers.sh"

setup minimal
cp shared/hello.go "$rootfs/hello.go"
chroot "$rootfs" /usr/lib/go-1.27/bin/go run /hello.go | grep "Hello, World!"
