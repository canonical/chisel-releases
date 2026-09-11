set -eu
source "$(dirname "$0")/helpers.sh"

# dash is the login shell of the test user, not something sshd needs
rootfs="$(install-slices openssh-server_bins dash_bins)"
trap cleanup EXIT
prepare_sshd "$rootfs"
write_sshd_config "$rootfs"
chroot "$rootfs" /usr/sbin/sshd -t -f /etc/ssh/sshd_config

# a config check does not exec sshd-session or sshd-auth, only a login does
start_sshd "$rootfs"
chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 'echo "hello from $SSH_CONNECTION"' \
  | grep -Fq "hello from 127.0.0.1 "
