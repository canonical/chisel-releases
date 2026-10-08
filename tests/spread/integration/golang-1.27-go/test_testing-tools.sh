source "$(dirname "$0")/helpers.sh"

setup testing-tools
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool cover -V
