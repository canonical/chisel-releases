(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool pack --help 2>&1 || true) | grep "Usage"
