(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool fix --help 2>&1 || true) | grep "usage"
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool nm --help 2>&1 || true) | grep "usage"
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool objdump --help 2>&1 || true) | grep "usage"
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool trace --help 2>&1 || true) | grep "Usage"
