(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool buildid 2>&1 || true) | grep "usage"
