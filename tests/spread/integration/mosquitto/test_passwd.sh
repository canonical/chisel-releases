rootfs="$(install-slices mosquitto_passwd)"
mkdir -p "$rootfs/tmp"

chroot "$rootfs" mosquitto_passwd -c -b /tmp/passwd alice alicepass
chroot "$rootfs" mosquitto_passwd -b /tmp/passwd bob bobpass
grep -Eq '^alice:\$[0-9]+\$' "$rootfs/tmp/passwd"
grep -Eq '^bob:\$[0-9]+\$' "$rootfs/tmp/passwd"

chroot "$rootfs" mosquitto_passwd -D /tmp/passwd alice
(! grep -q '^alice:' "$rootfs/tmp/passwd")
grep -q '^bob:' "$rootfs/tmp/passwd"
