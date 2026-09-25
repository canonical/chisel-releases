source "$(dirname "$0")/helpers.sh"

# dash is the login shell of the test user, not something sshd needs
rootfs="$(install-slices openssh-server_config openssh-server_bins dash_bins)"
trap cleanup_sshd EXIT
prepare_sshd "$rootfs"

# the default config has "UsePAM yes", so we should be using the PAM stack
start_sshd "$rootfs"
chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 'echo "hello from $SSH_CONNECTION"' \
  | grep -Fq "hello from 127.0.0.1 "

# pam_nologin from that stack: with /etc/nologin in place the same login is refused
echo "no logins" > "$rootfs/etc/nologin"
! chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 true
