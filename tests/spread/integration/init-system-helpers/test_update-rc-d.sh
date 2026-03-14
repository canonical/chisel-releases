#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices init-system-helpers_update-rc-d)"

chroot "$rootfs" /usr/sbin/update-rc.d --help 2>&1 | grep -q "usage: update-rc.d"

# Create test init script
# NOTE: the header comment here is the LSB init script format header. it is
#       parsed by update-rc.d to determine the runlevels and priorities for
#       the symlinks it creates
mkdir -p "$rootfs/etc/init.d"
cat > "$rootfs/etc/init.d/test" << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          test
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Test init script
### END INIT INFO

case "$1" in
    start) echo "starting test" ;;
    stop) echo "stopping test" ;;
    *) echo "usage: $0 {start|stop}"; exit 1 ;;
esac
EOF
chmod +x "$rootfs/etc/init.d/test"

chroot "$rootfs" /usr/sbin/update-rc.d test defaults

# find all files under /etc which are in rc*.d and are symlinks to /etc/init.d/test
# find "$rootfs/etc" -type l -path "*/rc*.d/*" -exec readlink -f {} \; | \
#     sed "s|$rootfs||" | sort -u | grep -qx "/etc/init.d/test"
for rl in 0 1 2 3 4 5 6; do
    link=$(find "$rootfs/etc/rc$rl.d" -type l | sed "s|$rootfs||");
    readlink -f "$rootfs$link" | grep -q "/etc/init.d/test"
done

# check that run levels 2,3,4 and 5 have S symlinks, and 0,1 and 6 have K symlinks
for rl in 2 3 4 5; do test -L "$rootfs/etc/rc$rl.d/S01test"; done
for rl in 0 1 6; do test -L "$rootfs/etc/rc$rl.d/K01test"; done

# test disable (K links)
chroot "$rootfs" /usr/sbin/update-rc.d test disable
for rl in 0 1 2 3 4 5 6; do test -L "$rootfs/etc/rc$rl.d/K01test"; done

# test enable (S links)
chroot "$rootfs" /usr/sbin/update-rc.d test enable
for rl in 2 3 4 5; do test -L "$rootfs/etc/rc$rl.d/S01test"; done
for rl in 0 1 6; do test -L "$rootfs/etc/rc$rl.d/K01test"; done

# test remove
chroot "$rootfs" /usr/sbin/update-rc.d test remove
for rl in 0 1 2 3 4 5 6; do
    test ! -L "$rootfs/etc/rc$rl.d/S01test"
    test ! -L "$rootfs/etc/rc$rl.d/K01test"
done
