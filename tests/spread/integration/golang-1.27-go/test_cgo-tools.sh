source "$(dirname "$0")/helpers.sh"

setup cgo-tools
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool cgo -V
cp shared/main_cgo.go "$rootfs/main_cgo.go"
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool cgo main_cgo.go
# since go 1.27 cgo writes into -objdir _obj by default
grep -Fq "hello_from_c" "$rootfs/_obj/_cgo_2.o"
