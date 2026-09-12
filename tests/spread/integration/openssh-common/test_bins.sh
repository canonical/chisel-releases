rootfs="$(install-slices openssh-common_bins)"
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

# ssh-keygen: make a key, then read its fingerprint and public half back
chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -C test -f /key
chroot "$rootfs" ssh-keygen -l -f /key.pub | grep -Fq "(ED25519)"
test "$(chroot "$rootfs" ssh-keygen -y -f /key | cut -d " " -f 2)" \
  = "$(cut -d " " -f 2 "$rootfs/key.pub")"

# the helpers serve ssh over their stdin, so on their own they can only
# show that they load and start
chroot "$rootfs" /usr/lib/openssh/ssh-sk-helper -h 2>&1 | grep -Fq "usage: ssh-sk-helper"
chroot "$rootfs" /usr/lib/openssh/ssh-pkcs11-helper -v < /dev/null 2>&1 \
  | grep -Fq "read eof"
