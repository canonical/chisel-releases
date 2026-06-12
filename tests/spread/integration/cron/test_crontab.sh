rootfs="$(install-slices cron_crontab)"
test -x "$rootfs/usr/bin/crontab"
test -f "$rootfs/etc/supercat/spcrc-crontab"
test -f "$rootfs/etc/supercat/spcrc-crontab-light"

# crontab needs /var/spool/cron/crontabs to store user crontabs
mkdir -p "$rootfs/var/spool/cron/crontabs"

echo "* * * * * /usr/bin/my-job" > "$rootfs/tmp/root.cron"
chroot "$rootfs" /usr/bin/crontab /tmp/root.cron
test "$(chroot "$rootfs" /usr/bin/crontab -l)" = "* * * * * /usr/bin/my-job"