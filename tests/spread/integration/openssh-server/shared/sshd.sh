# helpers for the variants that run sshd inside a rootfs

mounted=()

mount_rootfs() {
  mkdir -p "$1/dev" "$1/proc"
  mount --bind /dev "$1/dev"
  mount --bind /dev/pts "$1/dev/pts"
  mount --bind /proc "$1/proc"
  mounted+=("$1")
}

cleanup() {
  local rootfs
  if [ -n "${sshd_pid:-}" ]; then
    kill "$sshd_pid" || true
    cat "$sshd_rootfs/sshd.log"
  fi
  for rootfs in "${mounted[@]}"; do
    umount "$rootfs/dev/pts" || true
    umount "$rootfs/proc" || true
    umount "$rootfs/dev" || true
  done
}

# the privsep user is normally created by the sysusers snippet and the host
# keys by the postinst; tester is who the tests log in as
prepare_sshd() {
  local rootfs="$1"
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

  # the default "!" password would count as a locked account
  useradd -R "$rootfs" -m -u 1000 -s /usr/bin/sh -p "*" tester
  mkdir -p -m 0700 "$rootfs/root/.ssh" "$rootfs/home/tester/.ssh"
  chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /root/.ssh/id_ed25519
  cp "$rootfs/root/.ssh/id_ed25519.pub" "$rootfs/home/tester/.ssh/authorized_keys"
  chmod 0600 "$rootfs/home/tester/.ssh/authorized_keys"
  chown -R 1000 "$rootfs/home/tester/.ssh"
}

# runs sshd in the background and waits for it to listen
start_sshd() {
  sshd_rootfs="$1"
  chroot "$sshd_rootfs" /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config 2> "$sshd_rootfs/sshd.log" &
  sshd_pid=$!
  for _ in $(seq 60); do
    : 2> /dev/null > /dev/tcp/127.0.0.1/2222 && break
    kill -0 "$sshd_pid"
    sleep 0.5
  done
}

ssh_opts=(
  -p 2222
  -i /root/.ssh/id_ed25519
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)
