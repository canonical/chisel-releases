set -eu
rootfs="$(install-slices openssh-server_scripts)"

trap 'umount "$rootfs/proc" || true' EXIT
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"

# no interactive sshd sessions around, so nothing to kill and nothing to say
test -z "$(chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup 2>&1)"
