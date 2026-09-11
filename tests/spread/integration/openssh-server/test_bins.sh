set -eu
# dash is the login shell of the test user, not something sshd needs
rootfs="$(install-slices openssh-server_bins dash_bins)"

cleanup() {
  if [ -n "${sshd_pid:-}" ]; then
    kill "$sshd_pid" || true
    cat "$rootfs/sshd.log"
  fi
  umount "$rootfs/proc" || true
  umount "$rootfs/dev" || true
}
trap cleanup EXIT
mkdir -p "$rootfs/dev" "$rootfs/proc"
mount --bind /dev "$rootfs/dev"
mount --bind /proc "$rootfs/proc"

useradd -R "$rootfs" -r -g nogroup -d /run/sshd -s /usr/sbin/nologin sshd
mkdir -p "$rootfs/etc/ssh"
chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
cat > "$rootfs/etc/ssh/sshd_config" <<'EOF'
Port 2222
HostKey /etc/ssh/ssh_host_ed25519_key
PubkeyAuthentication yes
PasswordAuthentication no
UsePAM no
PidFile none
EOF
chroot "$rootfs" /usr/sbin/sshd -t -f /etc/ssh/sshd_config

# a user to log in as; the default "!" password would count as a locked account
useradd -R "$rootfs" -m -u 1000 -s /usr/bin/sh -p "*" tester
mkdir -p -m 0700 "$rootfs/root/.ssh" "$rootfs/home/tester/.ssh"
chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /root/.ssh/id_ed25519
cp "$rootfs/root/.ssh/id_ed25519.pub" "$rootfs/home/tester/.ssh/authorized_keys"
chmod 0600 "$rootfs/home/tester/.ssh/authorized_keys"
chown -R 1000 "$rootfs/home/tester/.ssh"

# a config check does not exec sshd-session or sshd-auth, only a login does
chroot "$rootfs" /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config 2> "$rootfs/sshd.log" &
sshd_pid=$!
for _ in $(seq 60); do
  : 2> /dev/null > /dev/tcp/127.0.0.1/2222 && break
  kill -0 "$sshd_pid"
  sleep 0.5
done
ssh_opts=(
  -p 2222
  -i /root/.ssh/id_ed25519
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)
chroot "$rootfs" ssh "${ssh_opts[@]}" tester@127.0.0.1 'echo "hello from $SSH_CONNECTION"' \
  | grep -Fq "hello from 127.0.0.1 "
