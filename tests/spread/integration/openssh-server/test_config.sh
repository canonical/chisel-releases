set -eu
source "$(dirname "$0")/helpers.sh"

# dash is the login shell of the test user, not something sshd needs
rootfs="$(install-slices openssh-server_config openssh-server_bins dash_bins)"
trap cleanup EXIT
prepare_sshd "$rootfs"

# the mutate script installs the default config where sshd looks for it
cmp "$rootfs/etc/ssh/sshd_config" "$rootfs/usr/share/openssh/sshd_config"

# a login through the shipped config: UsePAM yes, so /etc/pam.d/sshd and the
# pam stack behind it are in play
start_sshd "$rootfs"
chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 'echo "hello from $SSH_CONNECTION"' \
  | grep -Fq "hello from 127.0.0.1 "

# pam_nologin from that stack: with /etc/nologin in place the same login is refused
echo "no logins" > "$rootfs/etc/nologin"
! chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 true
