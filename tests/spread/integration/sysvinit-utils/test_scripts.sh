#!/bin/bash
#spellchecker: ignore rootfs sysvinit

rootfs="$(install-slices sysvinit-utils_scripts)"

mkdir -p "$rootfs/dev" "$rootfs/proc"
mount --rbind /dev "$rootfs/dev"
mount --rbind /proc "$rootfs/proc"
trap "umount -l '$rootfs/proc' || true; umount -l '$rootfs/dev' || true" EXIT

chroot "$rootfs" /usr/lib/init/init-d-script /usr/lib/init/init-d-script start

# unknown action should print usage and exit 3
mkdir -p "$rootfs/etc/init.d"
cat <<'EOF' > "$rootfs/etc/init.d/fake-service"
DAEMON=none
NAME=fake-service
DESC="Fake Service"
EOF
chmod +x "$rootfs/etc/init.d/fake-service"

code=0
chroot "$rootfs" /usr/lib/init/init-d-script /etc/init.d/fake-service unknown-action 2>&1 || code=$?
test "$code" -eq 3
chroot "$rootfs" /usr/lib/init/init-d-script /etc/init.d/fake-service unknown-action 2>&1 | grep -qi "usage"

# after stop, status should report not running (exit 3) and the pidfile removed
code=0
chroot "$rootfs" /usr/lib/init/init-d-script /etc/init.d/fake-service status 2>&1 || code=$?
test "$code" -eq 3
test ! -f "$rootfs/var/run/fake-service.pid"