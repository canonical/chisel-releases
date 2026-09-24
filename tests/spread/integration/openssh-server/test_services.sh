source "$(dirname "$0")/helpers.sh"

# the client and dash, the test user's login shell, are not things sshd needs
rootfs="$(install-slices openssh-server_services openssh-client_bins dash_bins)"
trap cleanup_sshd EXIT
prepare_sshd "$rootfs"

# a nondefault port reaches ssh.socket through the generator
echo "Port 2222" > "$rootfs/etc/ssh/sshd_config.d/port.conf"
mkdir -p "$rootfs/gen"
chroot "$rootfs" /usr/lib/systemd/system-generators/sshd-socket-generator /gen /gen /gen
grep -Fxq "ListenStream=0.0.0.0:2222" "$rootfs/gen/ssh.socket.d/addresses.conf"

# ssh.service checks the config, then serves the socket ssh.socket hands it
chroot "$rootfs" /usr/sbin/sshd -t
sshd_rootfs="$rootfs"
systemd-socket-activate -l 0.0.0.0:2222 \
  chroot "$rootfs" /usr/sbin/sshd -D -e 2> "$rootfs/sshd.log" &
sshd_pid=$!
wait_sshd
chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 'echo "hello from $SSH_CONNECTION"' \
  | grep -Fq "hello from 127.0.0.1 "
