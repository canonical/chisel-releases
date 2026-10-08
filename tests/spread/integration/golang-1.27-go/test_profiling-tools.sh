source "$(dirname "$0")/helpers.sh"

setup profiling-tools
(chroot "$rootfs" /usr/lib/go-1.27/bin/go tool preprofile 2>&1 || true) | grep "usage"
