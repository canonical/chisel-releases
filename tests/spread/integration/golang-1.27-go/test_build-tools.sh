source "$(dirname "$0")/helpers.sh"

setup build-tools
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool asm -V
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool compile -V
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool link -V
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool vet -V
