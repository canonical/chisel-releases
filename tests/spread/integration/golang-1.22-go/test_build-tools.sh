chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool asm -V
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool buildid 2>&1 || true) | grep "usage"
chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool compile -V
chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool link -V
(chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool pack --help 2>&1 || true) | grep "Usage"
chroot "${rootfs}" /usr/lib/go-1.22/bin/go tool vet -V
