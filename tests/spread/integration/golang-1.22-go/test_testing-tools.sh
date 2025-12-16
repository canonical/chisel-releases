(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool covdata --help 2>&1 || true) | grep "usage"
chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool cover -V
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool test2json --help 2>&1 || true) | grep "usage"
