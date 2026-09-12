source "$(dirname "$0")/helpers.sh"

# dash is the login shell of the test user, not something sshd needs
rootfs="$(install-slices openssh-server_bins dash_bins)"
trap cleanup_sshd EXIT
prepare_sshd "$rootfs"
cat > "$rootfs/etc/ssh/sshd_config" <<'EOF'
HostKey /etc/ssh/ssh_host_ed25519_key
PubkeyAuthentication yes
PasswordAuthentication no
UsePAM no
PidFile none
EOF

# check config parses and the host key is loaded
chroot "$rootfs" /usr/sbin/sshd -t -f /etc/ssh/sshd_config

# a config check does not exec sshd-session or sshd-auth, only a login does
start_sshd "$rootfs"
chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 'echo "hello from $SSH_CONNECTION"' \
  | grep -Fq "hello from 127.0.0.1 "
