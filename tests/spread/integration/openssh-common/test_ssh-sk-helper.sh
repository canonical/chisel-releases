rootfs="$(install-slices openssh-common_ssh-sk-helper)"
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

# the helper serves ssh over its stdin and needs a FIDO device to do more,
# so on its own it can only show that it loads and starts
chroot "$rootfs" /usr/lib/openssh/ssh-sk-helper -h 2>&1 | grep -Fq "usage: ssh-sk-helper"
