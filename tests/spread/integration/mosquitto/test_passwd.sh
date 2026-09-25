rootfs="$(install-slices mosquitto_passwd)"
mkdir -p "$rootfs/tmp"

chroot "$rootfs" mosquitto_passwd -c -b /tmp/passwd alice alicepass
chroot "$rootfs" mosquitto_passwd -b /tmp/passwd bob bobpass
grep -Eq '^alice:\$[0-9]+\$' "$rootfs/tmp/passwd"
grep -Eq '^bob:\$[0-9]+\$' "$rootfs/tmp/passwd"

chroot "$rootfs" mosquitto_passwd -D /tmp/passwd alice
if grep -q '^alice:' "$rootfs/tmp/passwd"; then
  printf 'alice is still in the password file\n' >&2
  exit 1
fi
grep -q '^bob:' "$rootfs/tmp/passwd"
