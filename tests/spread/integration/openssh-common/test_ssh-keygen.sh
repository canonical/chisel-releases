rootfs="$(install-slices openssh-common_ssh-keygen)"
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

# make a key, then read its fingerprint and public half back
chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -C test -f /key
chroot "$rootfs" ssh-keygen -l -f /key.pub | grep -Fq "(ED25519)"
test "$(chroot "$rootfs" ssh-keygen -y -f /key | cut -d " " -f 2)" \
  = "$(cut -d " " -f 2 "$rootfs/key.pub")"
