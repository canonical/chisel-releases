source "$(dirname "$0")/helpers.sh"

setup fix-tools
chroot "$rootfs" /usr/lib/go-1.27/bin/go tool fix -V
