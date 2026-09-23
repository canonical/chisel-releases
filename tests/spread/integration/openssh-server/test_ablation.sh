#!/bin/bash
set -euo pipefail

rootfs=$(install-slices openssh-server_bins openssh-server_config openssh-server_services)

# Each cut is disposable; restore a binary only when its failure was expected.
ablate() {
  local binary="$rootfs$1"
  shift
  mv "$binary" "$binary.disabled"
  if "$@" >/dev/null 2>&1; then
    echo "Unexpected success without $binary" >&2
    return 1
  fi
  mv "$binary.disabled" "$binary"
}

# Start the sliced server and authenticate with a temporary key.
mkdir -p "$rootfs/dev" "$rootfs/root" "$rootfs/run/sshd" "$rootfs/tmp"
touch "$rootfs/dev/null"
printf 'sshd:x:100:65534::/run/sshd:/usr/sbin/nologin\n' >> "$rootfs/etc/passwd"
printf 'root:*:0:0:99999:7:::\n' > "$rootfs/etc/shadow"
chmod 600 "$rootfs/etc/shadow"
sed -i '/^root:/s#[^:]*$#/usr/bin/dash#' "$rootfs/etc/passwd"
ssh-keygen -q -t ed25519 -N '' -f "$rootfs/tmp/key"
cat > "$rootfs/tmp/sshd.conf" <<'CONFIG'
Port 22222
ListenAddress 127.0.0.1
HostKey /tmp/key
AuthorizedKeysFile /tmp/key.pub
PermitRootLogin yes
StrictModes no
UsePAM no
PasswordAuthentication no
PerSourcePenalties no
CONFIG

ssh_login() {
  local reply
  reply=$(timeout 10 ssh -F /dev/null -n -q -i "$rootfs/tmp/key" -p 22222 \
    -o BatchMode=yes -o ConnectTimeout=3 -o ConnectionAttempts=3 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@127.0.0.1 'printf chisel-ok') || return
  [[ $reply == chisel-ok ]]
}

chroot "$rootfs" /usr/sbin/sshd -D -f /tmp/sshd.conf > "$rootfs/tmp/sshd.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
ssh_login
for helper in sshd-session sshd-auth; do
  ablate "/usr/lib/openssh/$helper" ssh_login
  ssh_login
done
ablate /usr/sbin/sshd chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf
chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf

# The socket generator must translate a custom port into a systemd override.
printf 'Port 22345\n' > "$rootfs/etc/ssh/sshd_config"
mkdir -p "$rootfs/tmp/gen/normal" "$rootfs/tmp/gen/early" "$rootfs/tmp/gen/late"
override="$rootfs/tmp/gen/normal/ssh.socket.d/addresses.conf"
run_generator() {
  chroot "$rootfs" /usr/lib/systemd/system-generators/sshd-socket-generator \
    /tmp/gen/normal /tmp/gen/early /tmp/gen/late
}

run_generator
grep -Fxq 'ListenStream=0.0.0.0:22345' "$override"
rm "$override"
ablate /usr/lib/systemd/system-generators/sshd-socket-generator run_generator
[[ ! -e $override ]]
grep -Fxq 'ListenStream=0.0.0.0:22' "$rootfs/usr/lib/systemd/system/ssh.socket"
run_generator
grep -Fxq 'ListenStream=0.0.0.0:22345' "$override"
