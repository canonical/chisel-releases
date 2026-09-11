#!/usr/bin/env bash
# helpers for the variants that run sshd inside a rootfs

mounted=()

# only for a pty login and for pgrep (/proc); a plain login needs nothing
# beyond the /dev/null prepare_sshd creates. /dev goes in with its submounts:
# on lxd /dev/ptmx is a bind mount of /dev/pts/ptmx, and openpty() needs both
mount_rootfs() {
  mkdir -p "$1/dev" "$1/proc"
  mount --rbind /dev "$1/dev"
  mount --make-rslave "$1/dev"
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
    umount --lazy "$rootfs/proc" || true
    umount --lazy "$rootfs/dev" || true
  done
}

# the privsep user is normally created by the sysusers snippet and the host
# keys by the postinst; tester is who the tests log in as, with the given shell
prepare_sshd() {
  local rootfs="$1" shell="${2:-/usr/bin/sh}"
  # install-slices hands out a 0700 dir; sshd reads authorized_keys as the
  # user, who then cannot get past the chroot's /
  chmod 755 "$rootfs"
  mkdir -p "$rootfs/dev" "$rootfs/etc/ssh"
  touch "$rootfs/dev/null"
  useradd --root "$rootfs" --system --gid nogroup --home-dir /run/sshd \
    --shell /usr/sbin/nologin sshd
  chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

  # the default "!" password would count as a locked account
  useradd --root "$rootfs" --create-home --uid 1000 --shell "$shell" --password "*" tester
  mkdir -p -m 0700 "$rootfs/root/.ssh" "$rootfs/home/tester/.ssh"
  chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /root/.ssh/id_ed25519
  cp "$rootfs/root/.ssh/id_ed25519.pub" "$rootfs/home/tester/.ssh/authorized_keys"
  chmod 0600 "$rootfs/home/tester/.ssh/authorized_keys"
  chown -R 1000 "$rootfs/home/tester/.ssh"
}

# a minimal config for the variants that do not ship one
write_sshd_config() {
  cat > "$1/etc/ssh/sshd_config" <<'EOF'
HostKey /etc/ssh/ssh_host_ed25519_key
PubkeyAuthentication yes
PasswordAuthentication no
UsePAM no
PidFile none
EOF
}

# runs sshd in the background, off the spread host's own port, and waits for
# it to listen
start_sshd() {
  sshd_rootfs="$1"
  chroot "$sshd_rootfs" /usr/sbin/sshd -D -e -p 2222 -f /etc/ssh/sshd_config \
    2> "$sshd_rootfs/sshd.log" &
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
