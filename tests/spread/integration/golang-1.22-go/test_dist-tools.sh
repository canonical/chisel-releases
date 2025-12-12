chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool dist version
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool distpack --help 2>&1 || true) | grep "usage"
