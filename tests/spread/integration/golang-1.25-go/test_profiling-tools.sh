(chroot "${rootfs}" /usr/lib/go-1.25/bin/go tool preprofile 2>&1 || true) | grep "usage"
