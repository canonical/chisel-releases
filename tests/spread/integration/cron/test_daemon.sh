rootfs="$(install-slices cron_daemon)"
test -x "$rootfs/usr/sbin/cron"

# cron needs these directories to start up
mkdir -p "$rootfs/var/spool"
mkdir -p "$rootfs/var/run"
mkdir -p "$rootfs/run"
mkdir -p "$rootfs/etc/cron.d"
echo 'crontab:x:107:' >> "$rootfs/etc/group"

# cron should stay running in foreground; timeout kills it after 2s.
timeout_rc=0
timeout 2 chroot "${rootfs}" /usr/sbin/cron -f || timeout_rc="$?"
test "${timeout_rc}" -eq 124